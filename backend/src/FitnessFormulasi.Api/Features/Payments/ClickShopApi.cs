using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace FitnessFormulasi.Api.Features.Payments;

/// <summary>Raw form fields of a Click Prepare (action=0) or Complete (action=1) request, as received.</summary>
public sealed record ClickRequest(
    string? ClickTransId, string? ServiceId, string? ClickPaydocId, string? MerchantTransId, string? MerchantPrepareId,
    string? Amount, string? Action, string? Error, string? ErrorNote, string? SignTime, string? SignString);

public sealed record ClickResponse(
    long ClickTransId, string MerchantTransId, long? MerchantPrepareId, long? MerchantConfirmId, int Error, string ErrorNote);

public sealed record ClickCredentials(long ServiceId, string SecretKey);

/// <summary>
/// Click SHOP API: Click calls the merchant twice — Prepare (check and reserve) and Complete (confirm or cancel).
/// Only a Complete with a valid signature and error = 0 confirms a payment; the user returning to a success page proves nothing.
/// Signature and error codes follow Click's official integration (click-llc/click-integration-php):
/// sign_string = md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id + [merchant_prepare_id, Complete only]
///                   + amount + action + sign_time).
/// </summary>
public sealed class ClickShopApi(ClickCredentials credentials, IPaymentOrderSource orders, IClickTransactionStore store)
{
    public const int Success = 0, SignFailed = -1, IncorrectAmount = -2, ActionNotFound = -3, AlreadyPaid = -4,
        OrderNotFound = -5, TransactionNotFound = -6, BadRequest = -8, TransactionCancelled = -9;

    public async Task<ClickResponse> HandleAsync(ClickRequest r, CancellationToken ct)
    {
        _ = long.TryParse(r.ClickTransId, NumberStyles.None, CultureInfo.InvariantCulture, out var clickTransId);
        var orderId = r.MerchantTransId ?? "";
        ClickResponse Fail(int code, string note, long? prepareId = null) => new(clickTransId, orderId, prepareId, null, code, note);

        if (clickTransId <= 0 || string.IsNullOrEmpty(r.ServiceId) || string.IsNullOrEmpty(orderId) || string.IsNullOrEmpty(r.Amount)
            || string.IsNullOrEmpty(r.Action) || string.IsNullOrEmpty(r.SignTime) || string.IsNullOrEmpty(r.SignString)
            || !int.TryParse(r.Error, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var clickError))
            return Fail(BadRequest, "Error in request from click");

        if (!SignatureValid(r)) return Fail(SignFailed, "SIGN CHECK FAILED!");
        if (r.Action is not ("0" or "1")) return Fail(ActionNotFound, "Action not found");
        if (r.ServiceId != credentials.ServiceId.ToString(CultureInfo.InvariantCulture)) return Fail(BadRequest, "Error in request from click");
        if (!decimal.TryParse(r.Amount, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var amount) || amount <= 0)
            return Fail(IncorrectAmount, "Incorrect parameter amount");

        var order = await orders.FindAsync(orderId, ct);
        if (order is null) return Fail(OrderNotFound, "User does not exist");

        if (r.Action == "0")
        {
            // A repeated Prepare with the same click_trans_id returns the same reservation (idempotent).
            var existing = await store.FindByClickTransIdAsync(clickTransId, ct);
            if (existing is not null && existing.OrderId != orderId) return Fail(BadRequest, "Error in request from click");
            if (existing?.State == ClickTransactionState.Cancelled) return Fail(TransactionCancelled, "Transaction cancelled");
            var orderError = CheckOrder(order, amount);
            if (orderError is not null) return Fail(orderError.Value.Code, orderError.Value.Note);
            var prepared = existing ?? await store.CreatePreparedAsync(clickTransId, orderId, ct);
            return new ClickResponse(clickTransId, orderId, prepared.PrepareId, null, Success, "Success");
        }

        if (!long.TryParse(r.MerchantPrepareId, NumberStyles.None, CultureInfo.InvariantCulture, out var prepareId))
            return Fail(TransactionNotFound, "Transaction does not exist");
        var tx = await store.FindByPrepareIdAsync(prepareId, ct);
        if (tx is null || tx.ClickTransId != clickTransId || tx.OrderId != orderId)
            return Fail(TransactionNotFound, "Transaction does not exist");
        // A repeated Complete for an already completed transaction gets the same confirmation (idempotent).
        if (tx.State == ClickTransactionState.Completed)
            return new ClickResponse(clickTransId, orderId, prepareId, tx.ConfirmId, Success, "Success");
        if (tx.State == ClickTransactionState.Cancelled) return Fail(TransactionCancelled, "Transaction cancelled", prepareId);

        // Click reports a failed payment with a negative error: the reservation is cancelled, nothing is paid.
        if (clickError < 0)
        {
            await store.CancelAsync(prepareId, ct);
            return Fail(TransactionCancelled, "Transaction cancelled", prepareId);
        }
        var error = CheckOrder(order, amount);
        if (error is not null) return Fail(error.Value.Code, error.Value.Note, prepareId);

        var completed = await store.CompleteAsync(prepareId, ct);
        return new ClickResponse(clickTransId, orderId, prepareId, completed.ConfirmId, Success, "Success");
    }

    public bool SignatureValid(ClickRequest r)
    {
        var expected = Sign(r, credentials.SecretKey);
        return CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected),
            Encoding.ASCII.GetBytes((r.SignString ?? "").ToLowerInvariant()));
    }

    /// <summary>Uses the raw strings exactly as Click sent them (e.g. amount "1000.00"), as Click signs them.</summary>
    public static string Sign(ClickRequest r, string secretKey)
    {
        var source = r.ClickTransId + r.ServiceId + secretKey + r.MerchantTransId + (r.Action == "1" ? r.MerchantPrepareId : "")
                     + r.Amount + r.Action + r.SignTime;
        return Convert.ToHexStringLower(MD5.HashData(Encoding.UTF8.GetBytes(source)));
    }

    private static (int Code, string Note)? CheckOrder(PaymentOrder order, decimal amount) =>
        order.State switch
        {
            PaymentOrderState.Paid => (AlreadyPaid, "Already paid"),
            PaymentOrderState.Cancelled => (TransactionCancelled, "Transaction cancelled"),
            _ when order.Currency != PaymentOrder.Uzs || order.Amount != amount => (IncorrectAmount, "Incorrect parameter amount"),
            _ => null,
        };
}
