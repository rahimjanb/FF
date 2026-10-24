using System.Text;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Features.Integrations;
using FitnessFormulasi.Api.Features.Payments;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Tests;

/// <summary>TEST-ONLY in-memory orders and transactions; production implementations come with stage 2.</summary>
internal sealed class FakeOrders : IPaymentOrderSource
{
    public Dictionary<string, PaymentOrder> Orders { get; } = [];
    public Task<PaymentOrder?> FindAsync(string orderId, CancellationToken ct) => Task.FromResult(Orders.GetValueOrDefault(orderId));
}

internal sealed class FakeClickStore(FakeOrders orders) : IClickTransactionStore
{
    public List<ClickTransaction> Items { get; } = [];
    private long _next = 100;

    public Task<ClickTransaction?> FindByClickTransIdAsync(long id, CancellationToken ct) => Task.FromResult(Items.FirstOrDefault(t => t.ClickTransId == id));
    public Task<ClickTransaction?> FindByPrepareIdAsync(long id, CancellationToken ct) => Task.FromResult(Items.FirstOrDefault(t => t.PrepareId == id));

    public Task<ClickTransaction> CreatePreparedAsync(long clickTransId, string orderId, CancellationToken ct)
    {
        var tx = new ClickTransaction(clickTransId, orderId, ++_next, ClickTransactionState.Prepared, null);
        Items.Add(tx);
        return Task.FromResult(tx);
    }

    public Task<ClickTransaction> CompleteAsync(long prepareId, CancellationToken ct)
    {
        var i = Items.FindIndex(t => t.PrepareId == prepareId);
        Items[i] = Items[i] with { State = ClickTransactionState.Completed, ConfirmId = prepareId + 1000 };
        orders.Orders[Items[i].OrderId] = orders.Orders[Items[i].OrderId] with { State = PaymentOrderState.Paid };
        return Task.FromResult(Items[i]);
    }

    public Task CancelAsync(long prepareId, CancellationToken ct)
    {
        var i = Items.FindIndex(t => t.PrepareId == prepareId);
        Items[i] = Items[i] with { State = ClickTransactionState.Cancelled };
        return Task.CompletedTask;
    }
}

internal sealed class FakePaymeStore(FakeOrders orders) : IPaymeTransactionStore
{
    public Dictionary<string, PaymeTransaction> Items { get; } = [];

    public Task<PaymeTransaction?> FindAsync(string id, CancellationToken ct) => Task.FromResult(Items.GetValueOrDefault(id));
    public Task<PaymeTransaction?> FindPendingForOrderAsync(string orderId, CancellationToken ct) =>
        Task.FromResult(Items.Values.FirstOrDefault(t => t.OrderId == orderId && t.State == PaymeState.Created));
    public Task<PaymeTransaction> CreateAsync(PaymeTransaction tx, CancellationToken ct)
    {
        tx = tx with { LocalId = "local-" + (Items.Count + 1) };
        Items[tx.PaymeId] = tx;
        return Task.FromResult(tx);
    }
    public Task UpdateAsync(PaymeTransaction tx, CancellationToken ct)
    {
        Items[tx.PaymeId] = tx;
        return Task.CompletedTask;
    }
    public Task PerformAsync(PaymeTransaction tx, CancellationToken ct)
    {
        Items[tx.PaymeId] = tx;
        orders.Orders[tx.OrderId] = orders.Orders[tx.OrderId] with { State = PaymentOrderState.Paid };
        return Task.CompletedTask;
    }
    public Task<IReadOnlyList<PaymeTransaction>> ListAsync(long from, long to, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<PaymeTransaction>>(Items.Values.Where(t => t.PaymeTime >= from && t.PaymeTime <= to).ToList());
}

public class SecretProtectorTests
{
    private static SecretProtector Create(string? key) => new(Options.Create(new IntegrationsOptions { EncryptionKey = key }));
    private static readonly string Key = Convert.ToBase64String(new byte[32].Select((_, i) => (byte)(i + 7)).ToArray());

    [Fact]
    public void Round_trip_is_bound_to_context_and_key()
    {
        var p = Create(Key);
        var c = p.Protect("s3cret-value", "Click/Test/secretKey");
        Assert.DoesNotContain("s3cret", c);
        Assert.NotEqual(c, p.Protect("s3cret-value", "Click/Test/secretKey")); // random nonce
        Assert.Equal("s3cret-value", p.Unprotect(c, "Click/Test/secretKey"));
        Assert.Null(p.Unprotect(c, "Click/Production/secretKey")); // copied to another field
        Assert.Null(Create(Convert.ToBase64String(new byte[32])).Unprotect(c, "Click/Test/secretKey")); // other key
        Assert.Null(p.Unprotect(c[..^4] + "AAAA", "Click/Test/secretKey")); // tampered
    }

    [Fact]
    public void Missing_key_disables_and_malformed_key_fails_fast()
    {
        Assert.False(Create(null).IsConfigured);
        Assert.Throws<InvalidOperationException>(() => Create("not base64!"));
        Assert.Throws<InvalidOperationException>(() => Create(Convert.ToBase64String(new byte[16])));
    }
}

public class ClickShopApiTests
{
    private const string Secret = "click-secret";
    private readonly FakeOrders _orders = new();
    private readonly FakeClickStore _store;
    private readonly ClickShopApi _api;

    public ClickShopApiTests()
    {
        _store = new FakeClickStore(_orders);
        _api = new ClickShopApi(new ClickCredentials(555, Secret), _orders, _store);
        _orders.Orders["order-1"] = new PaymentOrder("order-1", 150000m, PaymentOrder.Uzs, PaymentOrderState.AwaitingPayment);
    }

    private static ClickRequest Request(string action, string amount = "150000.00", string? prepareId = null, string error = "0",
        string clickTransId = "9001", string orderId = "order-1", string? sign = null)
    {
        var r = new ClickRequest(clickTransId, "555", "77", orderId, prepareId, amount, action, error, "", "2026-10-24 12:00:00", "");
        return r with { SignString = sign ?? ClickShopApi.Sign(r, Secret) };
    }

    [Fact]
    public void Signature_matches_the_official_formula()
    {
        // md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id + amount + action + sign_time) for Prepare
        var expected = Convert.ToHexStringLower(System.Security.Cryptography.MD5.HashData(
            Encoding.UTF8.GetBytes("9001" + "555" + Secret + "order-1" + "150000.00" + "0" + "2026-10-24 12:00:00")));
        Assert.Equal(expected, Request("0").SignString);
        // Complete inserts merchant_prepare_id after merchant_trans_id
        var complete = Convert.ToHexStringLower(System.Security.Cryptography.MD5.HashData(
            Encoding.UTF8.GetBytes("9001" + "555" + Secret + "order-1" + "101" + "150000.00" + "1" + "2026-10-24 12:00:00")));
        Assert.Equal(complete, Request("1", prepareId: "101").SignString);
    }

    [Fact]
    public async Task Invalid_signature_amount_order_and_action_are_rejected()
    {
        Assert.Equal(ClickShopApi.SignFailed, (await _api.HandleAsync(Request("0", sign: new string('0', 32)), default)).Error);
        Assert.Equal(ClickShopApi.IncorrectAmount, (await _api.HandleAsync(Request("0", amount: "149999.00"), default)).Error);
        Assert.Equal(ClickShopApi.OrderNotFound, (await _api.HandleAsync(Request("0", orderId: "missing"), default)).Error);
        Assert.Equal(ClickShopApi.ActionNotFound, (await _api.HandleAsync(Request("2"), default)).Error);
        Assert.Equal(ClickShopApi.BadRequest, (await _api.HandleAsync(Request("0") with { Error = null }, default)).Error);
        Assert.Empty(_store.Items);
    }

    [Fact]
    public async Task Prepare_and_complete_are_idempotent_and_only_complete_pays()
    {
        var p1 = await _api.HandleAsync(Request("0"), default);
        var p2 = await _api.HandleAsync(Request("0"), default);
        Assert.Equal(ClickShopApi.Success, p1.Error);
        Assert.Equal(p1.MerchantPrepareId, p2.MerchantPrepareId);
        Assert.Single(_store.Items);
        Assert.Equal(PaymentOrderState.AwaitingPayment, _orders.Orders["order-1"].State); // Prepare alone pays nothing

        var prepareId = p1.MerchantPrepareId!.Value.ToString();
        var c1 = await _api.HandleAsync(Request("1", prepareId: prepareId), default);
        var c2 = await _api.HandleAsync(Request("1", prepareId: prepareId), default);
        Assert.Equal(ClickShopApi.Success, c1.Error);
        Assert.Equal(c1.MerchantConfirmId, c2.MerchantConfirmId);
        Assert.Equal(PaymentOrderState.Paid, _orders.Orders["order-1"].State);

        // Another Click transaction for the paid order is refused.
        Assert.Equal(ClickShopApi.AlreadyPaid, (await _api.HandleAsync(Request("0", clickTransId: "9002"), default)).Error);
    }

    [Fact]
    public async Task Complete_with_click_error_cancels_and_unknown_prepare_is_rejected()
    {
        var prepareId = (await _api.HandleAsync(Request("0"), default)).MerchantPrepareId!.Value.ToString();
        Assert.Equal(ClickShopApi.TransactionNotFound, (await _api.HandleAsync(Request("1", prepareId: "999999"), default)).Error);

        var failed = await _api.HandleAsync(Request("1", prepareId: prepareId, error: "-5017"), default);
        Assert.Equal(ClickShopApi.TransactionCancelled, failed.Error);
        Assert.Equal(PaymentOrderState.AwaitingPayment, _orders.Orders["order-1"].State);
        Assert.Equal(ClickShopApi.TransactionCancelled, (await _api.HandleAsync(Request("1", prepareId: prepareId), default)).Error);
    }
}

public class PaymeMerchantApiTests
{
    private const string Key = "payme-test-key";
    private readonly FakeOrders _orders = new();
    private readonly FakePaymeStore _store;
    private readonly ManualTime _time = new(DateTimeOffset.Parse("2026-10-24T10:00:00Z"));
    private readonly PaymeMerchantApi _api;
    private static readonly string Auth = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes("Paycom:" + Key));

    private sealed class ManualTime(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;
        public override DateTimeOffset GetUtcNow() => Now;
    }

    public PaymeMerchantApiTests()
    {
        _store = new FakePaymeStore(_orders);
        _api = new PaymeMerchantApi(new PaymeCredentials(Key), _orders, _store, _time);
        _orders.Orders["order-1"] = new PaymentOrder("order-1", 150000m, PaymentOrder.Uzs, PaymentOrderState.AwaitingPayment);
    }

    private long Now => _time.Now.ToUnixTimeMilliseconds();

    private async Task<JsonObject> Call(string method, JsonObject p, string? auth = null) =>
        await _api.HandleAsync(auth ?? Auth, new JsonObject { ["jsonrpc"] = "2.0", ["id"] = 7, ["method"] = method, ["params"] = p }.ToJsonString(), default);

    private JsonObject Create(string id = "p-1", long amount = 15_000_000, string order = "order-1") => new()
    {
        ["id"] = id, ["time"] = Now, ["amount"] = amount, ["account"] = new JsonObject { ["order_id"] = order },
    };

    private static int? ErrorCode(JsonObject r) => (int?)r["error"]?["code"];

    [Fact]
    public async Task Wrong_or_missing_authorization_is_rejected_before_anything_else()
    {
        Assert.Equal(PaymeMerchantApi.Unauthorized, ErrorCode(await Call("CheckPerformTransaction", Create(), auth: "Basic " +
            Convert.ToBase64String(Encoding.UTF8.GetBytes("Paycom:wrong")))));
        Assert.Equal(PaymeMerchantApi.Unauthorized, ErrorCode(await Call("CheckPerformTransaction", Create(), auth: "")));
        Assert.Equal(PaymeMerchantApi.ParseError, ErrorCode(await _api.HandleAsync(Auth, "{not json", default)));
        Assert.Equal(PaymeMerchantApi.MethodNotFound, ErrorCode(await Call("Unknown", new JsonObject())));
    }

    [Fact]
    public async Task Amount_is_checked_in_tiyin_and_unknown_order_is_an_account_error()
    {
        Assert.True((bool)(await Call("CheckPerformTransaction", Create()))["result"]!["allow"]!);
        Assert.Equal(PaymeMerchantApi.InvalidAmount, ErrorCode(await Call("CheckPerformTransaction", Create(amount: 150000))));
        var missing = await Call("CheckPerformTransaction", Create(order: "nope"));
        Assert.Equal(PaymeMerchantApi.OrderNotFound, ErrorCode(missing));
        Assert.Equal("order_id", (string?)missing["error"]!["data"]);
    }

    [Fact]
    public async Task Create_and_perform_are_idempotent_and_only_perform_pays()
    {
        var c1 = await Call("CreateTransaction", Create());
        var c2 = await Call("CreateTransaction", Create());
        Assert.Equal(1, (int)c1["result"]!["state"]!);
        Assert.Equal((string?)c1["result"]!["transaction"], (string?)c2["result"]!["transaction"]);
        Assert.Equal(PaymentOrderState.AwaitingPayment, _orders.Orders["order-1"].State);

        // A second Payme transaction for the same order is refused while the first is pending.
        Assert.Equal(PaymeMerchantApi.OrderHasPendingTransaction, ErrorCode(await Call("CreateTransaction", Create(id: "p-2"))));

        var perform = new JsonObject { ["id"] = "p-1" };
        var p1 = await Call("PerformTransaction", perform);
        var p2 = await Call("PerformTransaction", new JsonObject { ["id"] = "p-1" });
        Assert.Equal(2, (int)p1["result"]!["state"]!);
        Assert.Equal((long)p1["result"]!["perform_time"]!, (long)p2["result"]!["perform_time"]!);
        Assert.Equal(PaymentOrderState.Paid, _orders.Orders["order-1"].State);

        var check = await Call("CheckTransaction", new JsonObject { ["id"] = "p-1" });
        Assert.Equal(2, (int)check["result"]!["state"]!);
        Assert.Equal(PaymeMerchantApi.TransactionNotFound, ErrorCode(await Call("CheckTransaction", new JsonObject { ["id"] = "zzz" })));
    }

    [Fact]
    public async Task Pending_transaction_times_out_after_12_hours()
    {
        await Call("CreateTransaction", Create());
        _time.Now = _time.Now.AddMilliseconds(PaymeMerchantApi.TransactionTimeoutMs + 1);
        Assert.Equal(PaymeMerchantApi.CannotPerform, ErrorCode(await Call("PerformTransaction", new JsonObject { ["id"] = "p-1" })));
        Assert.Equal(PaymeState.Cancelled, _store.Items["p-1"].State);
        Assert.Equal(4, _store.Items["p-1"].Reason);
        Assert.Equal(PaymentOrderState.AwaitingPayment, _orders.Orders["order-1"].State);
    }

    [Fact]
    public async Task Cancel_before_and_after_perform()
    {
        await Call("CreateTransaction", Create());
        var cancel = await Call("CancelTransaction", new JsonObject { ["id"] = "p-1", ["reason"] = 3 });
        Assert.Equal(-1, (int)cancel["result"]!["state"]!);
        var again = await Call("CancelTransaction", new JsonObject { ["id"] = "p-1", ["reason"] = 3 });
        Assert.Equal((long)cancel["result"]!["cancel_time"]!, (long)again["result"]!["cancel_time"]!);
        Assert.Equal(PaymeMerchantApi.CannotPerform, ErrorCode(await Call("PerformTransaction", new JsonObject { ["id"] = "p-1" })));

        // After perform a refund is allowed only while the service was not provided yet.
        await Call("CreateTransaction", Create(id: "p-2"));
        await Call("PerformTransaction", new JsonObject { ["id"] = "p-2" });
        _orders.Orders["order-1"] = _orders.Orders["order-1"] with { IsFulfilled = true };
        Assert.Equal(PaymeMerchantApi.CannotCancel, ErrorCode(await Call("CancelTransaction", new JsonObject { ["id"] = "p-2", ["reason"] = 5 })));
        _orders.Orders["order-1"] = _orders.Orders["order-1"] with { IsFulfilled = false };
        Assert.Equal(-2, (int)(await Call("CancelTransaction", new JsonObject { ["id"] = "p-2", ["reason"] = 5 }))["result"]!["state"]!);
    }
}
