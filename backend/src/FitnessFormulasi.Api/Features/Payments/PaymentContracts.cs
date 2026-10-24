namespace FitnessFormulasi.Api.Features.Payments;

// Stage 2 groundwork. Nothing here is registered in DI and no HTTP endpoint uses it yet: online payments are not
// accepted in stage 1. Orders and transaction storage will be implemented together with the payment endpoints.

public enum PaymentOrderState { AwaitingPayment, Paid, Cancelled }

/// <summary>An order the club wants paid. Amounts are in UZS (sum); Click sends sums, Payme sends tiyin (1/100).</summary>
public sealed record PaymentOrder(string Id, decimal Amount, string Currency, PaymentOrderState State, bool IsFulfilled = false)
{
    public const string Uzs = "UZS";
}

public interface IPaymentOrderSource
{
    Task<PaymentOrder?> FindAsync(string orderId, CancellationToken ct);
}

// ---- Click SHOP API ----

public enum ClickTransactionState { Prepared, Completed, Cancelled }

public sealed record ClickTransaction(long ClickTransId, string OrderId, long PrepareId, ClickTransactionState State, long? ConfirmId);

/// <summary>Persistent Click transactions. Implementations must keep click_trans_id unique (database constraint).</summary>
public interface IClickTransactionStore
{
    Task<ClickTransaction?> FindByClickTransIdAsync(long clickTransId, CancellationToken ct);
    Task<ClickTransaction?> FindByPrepareIdAsync(long prepareId, CancellationToken ct);
    Task<ClickTransaction> CreatePreparedAsync(long clickTransId, string orderId, CancellationToken ct);
    /// <summary>Marks the transaction completed and the order paid in one database transaction.</summary>
    Task<ClickTransaction> CompleteAsync(long prepareId, CancellationToken ct);
    Task CancelAsync(long prepareId, CancellationToken ct);
}

// ---- Payme Merchant API ----

/// <summary>Payme transaction states: 1 created, 2 performed, -1 cancelled before perform, -2 cancelled after perform.</summary>
public static class PaymeState
{
    public const int Created = 1, Performed = 2, Cancelled = -1, CancelledAfterPerform = -2;
}

/// <summary>Times are Unix milliseconds, as in the Payme protocol. Amount is in tiyin.</summary>
public sealed record PaymeTransaction(
    string PaymeId, string OrderId, long Amount, long PaymeTime, long CreateTime, long PerformTime, long CancelTime,
    int State, int? Reason, string LocalId);

public interface IPaymeTransactionStore
{
    Task<PaymeTransaction?> FindAsync(string paymeId, CancellationToken ct);
    /// <summary>A transaction of the order in state 1 (created, not yet performed or cancelled).</summary>
    Task<PaymeTransaction?> FindPendingForOrderAsync(string orderId, CancellationToken ct);
    Task<PaymeTransaction> CreateAsync(PaymeTransaction transaction, CancellationToken ct);
    Task UpdateAsync(PaymeTransaction transaction, CancellationToken ct);
    /// <summary>Saves state 2 and marks the order paid in one database transaction.</summary>
    Task PerformAsync(PaymeTransaction transaction, CancellationToken ct);
    Task<IReadOnlyList<PaymeTransaction>> ListAsync(long fromPaymeTime, long toPaymeTime, CancellationToken ct);
}
