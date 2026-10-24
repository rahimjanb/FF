using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FitnessFormulasi.Api.Features.Payments;

/// <summary>The cash register key: TEST_KEY in the sandbox (test.paycom.uz), "key" in production.</summary>
public sealed record PaymeCredentials(string Key);

/// <summary>
/// Payme Merchant API (JSON-RPC 2.0 over HTTPS POST, always HTTP 200). Payme Business calls the merchant's billing:
/// CheckPerformTransaction, CreateTransaction, PerformTransaction, CancelTransaction, CheckTransaction, GetStatement.
/// A payment is confirmed only by PerformTransaction from Payme with valid authorization — never by a redirect.
/// Amounts are tiyin; times are Unix milliseconds; an unperformed transaction is cancelled after 12 hours (reason 4).
/// </summary>
public sealed class PaymeMerchantApi(PaymeCredentials credentials, IPaymentOrderSource orders, IPaymeTransactionStore store, TimeProvider time)
{
    /// <summary>Order id is passed in params.account under this name (configured in the Payme cabinet).</summary>
    public const string AccountField = "order_id";
    public const long TransactionTimeoutMs = 43_200_000;

    public const int InvalidAmount = -31001, TransactionNotFound = -31003, CannotCancel = -31007, CannotPerform = -31008,
        OrderNotFound = -31050, OrderNotPayable = -31051, OrderHasPendingTransaction = -31052,
        Unauthorized = -32504, MethodNotFound = -32601, InvalidRequest = -32600, ParseError = -32700, SystemError = -32400;

    private sealed class RpcError(int code, string ru, string uz, string en, string? data = null) : Exception(en)
    {
        public JsonObject ToJson() => new()
        {
            ["code"] = code,
            ["message"] = new JsonObject { ["ru"] = ru, ["uz"] = uz, ["en"] = Message },
            ["data"] = data,
        };
    }

    public async Task<JsonObject> HandleAsync(string? authorization, string body, CancellationToken ct)
    {
        JsonNode? id = null;
        try
        {
            JsonObject request;
            try { request = JsonNode.Parse(body) as JsonObject ?? throw new JsonException(); }
            catch (JsonException) { throw new RpcError(ParseError, "Ошибка разбора JSON", "JSON xatosi", "Parse error"); }
            id = request["id"]?.DeepClone();
            if (!Authorized(authorization))
                throw new RpcError(Unauthorized, "Недостаточно привилегий", "Ruxsat yetarli emas", "Insufficient privileges");
            var method = (string?)request["method"];
            var p = request["params"] as JsonObject;
            if (method is null || p is null)
                throw new RpcError(InvalidRequest, "Неверный запрос", "Noto‘g‘ri so‘rov", "Invalid request");

            JsonObject result = method switch
            {
                "CheckPerformTransaction" => await CheckPerformAsync(p, ct),
                "CreateTransaction" => await CreateAsync(p, ct),
                "PerformTransaction" => await PerformAsync(p, ct),
                "CancelTransaction" => await CancelAsync(p, ct),
                "CheckTransaction" => Describe(await RequireAsync(p, ct)),
                "GetStatement" => await StatementAsync(p, ct),
                _ => throw new RpcError(MethodNotFound, "Метод не найден", "Metod topilmadi", "Method not found", method),
            };
            return new JsonObject { ["jsonrpc"] = "2.0", ["id"] = id, ["result"] = result };
        }
        catch (RpcError e)
        {
            return new JsonObject { ["jsonrpc"] = "2.0", ["id"] = id, ["error"] = e.ToJson() };
        }
        catch (Exception e) when (e is InvalidOperationException or FormatException or JsonException)
        {
            // Malformed parameter types (e.g. a string where a number is expected).
            return new JsonObject
            {
                ["jsonrpc"] = "2.0", ["id"] = id,
                ["error"] = new RpcError(InvalidRequest, "Неверный запрос", "Noto‘g‘ri so‘rov", "Invalid request").ToJson(),
            };
        }
    }

    /// <summary>HTTP Basic with login "Paycom" and the cash register key; compared in constant time.</summary>
    public bool Authorized(string? header)
    {
        if (header is null || !header.StartsWith("Basic ", StringComparison.Ordinal)) return false;
        string decoded;
        try { decoded = Encoding.UTF8.GetString(Convert.FromBase64String(header["Basic ".Length..].Trim())); }
        catch (FormatException) { return false; }
        var expected = Encoding.UTF8.GetBytes("Paycom:" + credentials.Key);
        return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(decoded), expected);
    }

    private async Task<JsonObject> CheckPerformAsync(JsonObject p, CancellationToken ct)
    {
        var order = await PayableOrderAsync(p, ct);
        if (await store.FindPendingForOrderAsync(order.Id, ct) is not null)
            throw new RpcError(OrderHasPendingTransaction, "Заказ уже оплачивается", "Buyurtma to‘lanmoqda", "Order is being paid", AccountField);
        return new JsonObject { ["allow"] = true };
    }

    private async Task<JsonObject> CreateAsync(JsonObject p, CancellationToken ct)
    {
        var paymeId = (string)p["id"]!;
        var now = Now();
        var existing = await store.FindAsync(paymeId, ct);
        if (existing is not null)
        {
            if (existing.State != PaymeState.Created) throw CannotPerformError();
            if (now - existing.CreateTime > TransactionTimeoutMs)
            {
                await store.UpdateAsync(existing with { State = PaymeState.Cancelled, Reason = 4, CancelTime = now }, ct);
                throw CannotPerformError();
            }
            return Created(existing);
        }

        var paymeTime = (long)p["time"]!;
        if (now - paymeTime > TransactionTimeoutMs) throw CannotPerformError();
        var order = await PayableOrderAsync(p, ct);
        if (await store.FindPendingForOrderAsync(order.Id, ct) is not null)
            throw new RpcError(OrderHasPendingTransaction, "Заказ уже оплачивается", "Buyurtma to‘lanmoqda", "Order is being paid", AccountField);

        var created = await store.CreateAsync(new PaymeTransaction(paymeId, order.Id, (long)p["amount"]!, paymeTime, now, 0, 0,
            PaymeState.Created, null, ""), ct);
        return Created(created);
    }

    private async Task<JsonObject> PerformAsync(JsonObject p, CancellationToken ct)
    {
        var tx = await RequireAsync(p, ct);
        var now = Now();
        switch (tx.State)
        {
            case PaymeState.Performed:
                return Performed(tx); // repeated call: same answer
            case PaymeState.Created when now - tx.CreateTime > TransactionTimeoutMs:
                await store.UpdateAsync(tx with { State = PaymeState.Cancelled, Reason = 4, CancelTime = now }, ct);
                throw CannotPerformError();
            case PaymeState.Created:
                var order = await orders.FindAsync(tx.OrderId, ct);
                if (order is null || order.State != PaymentOrderState.AwaitingPayment) throw CannotPerformError();
                var performed = tx with { State = PaymeState.Performed, PerformTime = now };
                await store.PerformAsync(performed, ct);
                return Performed(performed);
            default:
                throw CannotPerformError();
        }
    }

    private async Task<JsonObject> CancelAsync(JsonObject p, CancellationToken ct)
    {
        var tx = await RequireAsync(p, ct);
        var reason = (int)p["reason"]!;
        var now = Now();
        switch (tx.State)
        {
            case PaymeState.Created:
                tx = tx with { State = PaymeState.Cancelled, Reason = reason, CancelTime = now };
                await store.UpdateAsync(tx, ct);
                break;
            case PaymeState.Performed:
                var order = await orders.FindAsync(tx.OrderId, ct);
                if (order is null || order.IsFulfilled)
                    throw new RpcError(CannotCancel, "Услуга уже оказана, отмена невозможна", "Xizmat ko‘rsatilgan, bekor qilib bo‘lmaydi",
                        "Service already provided; cannot cancel");
                tx = tx with { State = PaymeState.CancelledAfterPerform, Reason = reason, CancelTime = now };
                await store.UpdateAsync(tx, ct);
                break;
        }
        // Already cancelled: the same answer is returned again.
        return new JsonObject { ["transaction"] = tx.LocalId, ["cancel_time"] = tx.CancelTime, ["state"] = tx.State };
    }

    private async Task<JsonObject> StatementAsync(JsonObject p, CancellationToken ct)
    {
        var list = await store.ListAsync((long)p["from"]!, (long)p["to"]!, ct);
        var items = new JsonArray();
        foreach (var tx in list)
        {
            var item = Describe(tx);
            item["id"] = tx.PaymeId;
            item["time"] = tx.PaymeTime;
            item["amount"] = tx.Amount;
            item["account"] = new JsonObject { [AccountField] = tx.OrderId };
            items.Add(item);
        }
        return new JsonObject { ["transactions"] = items };
    }

    /// <summary>Checks that the order exists, awaits payment, is in UZS and the amount in tiyin matches exactly.</summary>
    private async Task<PaymentOrder> PayableOrderAsync(JsonObject p, CancellationToken ct)
    {
        var orderId = (string?)p["account"]?[AccountField];
        var order = string.IsNullOrEmpty(orderId) ? null : await orders.FindAsync(orderId, ct);
        if (order is null)
            throw new RpcError(OrderNotFound, "Заказ не найден", "Buyurtma topilmadi", "Order not found", AccountField);
        if (order.State != PaymentOrderState.AwaitingPayment)
            throw new RpcError(OrderNotPayable, "Заказ уже оплачен или отменён", "Buyurtma to‘langan yoki bekor qilingan",
                "Order is already paid or cancelled", AccountField);
        var amount = (long)p["amount"]!;
        if (order.Currency != PaymentOrder.Uzs || amount <= 0 || order.Amount * 100 != amount)
            throw new RpcError(InvalidAmount, "Неверная сумма", "Noto‘g‘ri summa", "Invalid amount");
        return order;
    }

    private async Task<PaymeTransaction> RequireAsync(JsonObject p, CancellationToken ct) =>
        await store.FindAsync((string)p["id"]!, ct)
        ?? throw new RpcError(TransactionNotFound, "Транзакция не найдена", "Tranzaksiya topilmadi", "Transaction not found");

    private static JsonObject Created(PaymeTransaction tx) =>
        new() { ["create_time"] = tx.CreateTime, ["transaction"] = tx.LocalId, ["state"] = tx.State };

    private static JsonObject Performed(PaymeTransaction tx) =>
        new() { ["transaction"] = tx.LocalId, ["perform_time"] = tx.PerformTime, ["state"] = tx.State };

    private static JsonObject Describe(PaymeTransaction tx) => new()
    {
        ["create_time"] = tx.CreateTime, ["perform_time"] = tx.PerformTime, ["cancel_time"] = tx.CancelTime,
        ["transaction"] = tx.LocalId, ["state"] = tx.State, ["reason"] = tx.Reason,
    };

    private static RpcError CannotPerformError() =>
        new(CannotPerform, "Невозможно выполнить операцию", "Amalni bajarib bo‘lmaydi", "Unable to perform operation");

    private long Now() => time.GetUtcNow().ToUnixTimeMilliseconds();
}
