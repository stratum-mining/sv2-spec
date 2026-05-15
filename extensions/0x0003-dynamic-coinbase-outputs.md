# Stratum V2 Extension: Dynamic Coinbase Outputs

## 0. Abstract

This document defines a Stratum V2 extension that lets a Job Declaration Client (JDC) request, per declared job, the exact list of pool-defined coinbase outputs from the Job Declaration Server (JDS), given the JDC-reported revenue the pool is allowed to distribute. The extension introduces two new request/response messages: `RequestCoinbaseOutputs` (JDC → JDS) and its `RequestCoinbaseOutputs.Success` / `RequestCoinbaseOutputs.Error` responses.

The per-job output set is bounded only by the coinbase output space the JDC has already reserved with its Template Provider. That reservation is sized from `AllocateMiningJobToken.Success.coinbase_tx_outputs` exactly as base JDP already prescribes (§6.4.3, §7.1) — this extension adds no new coinbase-size-negotiation channel.

This generalizes the single-output rule defined in [Section 6.4.3](../06-Job-Declaration-Protocol.md#643-allocateminingjobtokensuccess-server---client). When negotiated, the pool's payout for a given declared job is no longer a single output carrying `template_revenue`, but an arbitrary, pool-computed list of outputs whose total amount is constrained only by the revenue the JDC reports it is contributing.

The motivating use case is non-custodial pooled mining via JDP, including PPLNS and PROP-style payouts whose output distribution depends on (a) the actual revenue at template time and (b) pool-internal state (per-miner shares in the current window, group memberships, pending balances, dust thresholds). Static parameters communicated at token allocation time cannot capture these inputs, because both change continuously over the lifetime of a single token.

Trustless share attestation, fee-vs-subsidy split policy, JDS↔Pool internal coordination, and any other concern beyond communicating the per-job output list are out of scope for this extension.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Overview

### 1.1 Why per-job instead of per-token

The existing `AllocateMiningJobToken.Success.coinbase_tx_outputs` (§6.4.3) is committed once when a token is issued and is intended to be reused across many declared jobs over the token's lifetime. For a single-output pool payout the field is sufficient: the pool's payout address is stable and the amount is implicitly `template_revenue` per Example A in §6.4.3.

For pooled payouts that distribute revenue across many recipients, neither half of that assumption holds:

- **Per-miner amounts depend on revenue.** A miner with a 1% share weight is paid 5 000 sat on a 500 000-sat block but 25 sat on a 2 500-sat block; the latter is below the dust threshold for every standard output type, so the pool's actual policy is to suppress the output and roll the amount into an internal pending balance. The same weight produces different on-chain output sets at different revenues. A static distribution committed at token allocation cannot express this.

- **Per-miner share weights drift continuously.** In a sliding-window PPLNS payout, every accepted share rotates the window: new shares enter, the oldest shares fall out, and the per-miner proportions change. A weight vector frozen at token allocation is stale within minutes of being issued.

This extension addresses both by moving the output-set decision from token allocation to declared-job time. The pool computes the exact output list at the moment it is needed, using current internal state and the JDC-reported revenue.

### 1.2 Negotiation

This extension is negotiated via the standard procedure defined in [Extension 0x0001](./0x0001-extensions-negotiation.md). The JDC sends `RequestExtensions [0x0003]` immediately after `SetupConnection.Success` on the JDP connection. If the JDS supports the extension, it responds with `RequestExtensions.Success [0x0003]`.

When this extension is not negotiated, the existing single-output rule of §6.4.3 applies unchanged.

### 1.3 Lifecycle Summary

1. The JDC obtains a `mining_job_token` via the standard `AllocateMiningJobToken` / `AllocateMiningJobToken.Success` exchange. As in base JDP, the JDC derives the coinbase output space to reserve from the serialized size of `AllocateMiningJobToken.Success.coinbase_tx_outputs` and communicates it to its Template Provider via `CoinbaseOutputConstraints` (§7.1). The pool sizes that field for the largest per-job set it anticipates under this token — computed at the maximum plausible revenue, and OPTIONALLY padded with `0`-value outputs for extra recipient-growth headroom (§4.3).
2. For each prospective declared job, the JDC sends `RequestCoinbaseOutputs` to the JDS, identifying the token, the template's `prev_hash`, and the amount of revenue (`pool_revenue`) it is contributing to the pool's output set.
3. The JDS responds with `RequestCoinbaseOutputs.Success` carrying a Bitcoin-consensus-serialized list of outputs whose total amount is at most `pool_revenue` and whose serialized size fits the space the JDC reserved in step 1, OR with `RequestCoinbaseOutputs.Error` if the request cannot be served (stale `prev_hash`, invalid token, etc.).
4. The JDC builds the coinbase (`DeclareMiningJob.coinbase_tx_suffix` in Full-Template mode, `SetCustomMiningJob.coinbase_tx_outputs` in Coinbase-only mode) containing those outputs.
5. The validating party (JDS in Full-Template mode, Pool in Coinbase-only mode) checks the declared coinbase against the most recent emitted `RequestCoinbaseOutputs.Success` for that token, ignoring the order of outputs and any JDC-added outputs as permitted by §6.4.3.

Detailed refresh rules and predictive prefetching are described in [Section 3 (Operational Semantics)](#3-operational-semantics).

---

## 2. Messages

This extension introduces three new messages. All have `extension_type = 0x0003` in the frame header per [Section 3.4.1](../03-Protocol-Overview.md#341-extension-type-field-usage). The `channel_msg` bit is unset.

### 2.1 `RequestCoinbaseOutputs` (JDC → JDS)

Sent by the JDC ahead of declaring a job, to obtain the exact list of pool-defined coinbase outputs for that job.

| Field Name         | Data Type | Description                                                                                                                                                             |
|--------------------|-----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `request_id`       | U32       | Unique identifier for pairing the response, scoped per JDP connection.                                                                                                  |
| `mining_job_token` | B0_255    | The token previously issued by `AllocateMiningJobToken.Success`. Identifies which JDC session this request belongs to.                                                  |
| `prev_hash`        | U256      | The `prev_hash` of the template the JDC intends to declare. Allows the JDS to detect requests against a state already paid out by a different block found in the meantime. |
| `pool_revenue`     | U64       | Sats the JDC is contributing to the pool's output set. Equal to `template_revenue` minus the sum of any outputs the JDC intends to add for itself per §6.4.3.            |

The JDC MAY send concurrent `RequestCoinbaseOutputs` messages with distinct `request_id` values (for example, when prefetching for a predicted next `prev_hash` while still mining the current one).

### 2.2 `RequestCoinbaseOutputs.Success` (JDS → JDC)

Sent by the JDS in response to a successful `RequestCoinbaseOutputs`.

| Field Name            | Data Type | Description                                                                                                                                                                                                                                                                                                                                                                                                                       |
|-----------------------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `request_id`          | U32       | Echoed from `RequestCoinbaseOutputs`.                                                                                                                                                                                                                                                                                                                                                                                             |
| `coinbase_tx_outputs` | B0_64K    | Bitcoin-consensus-serialized output list (CompactSize-prefixed array of consensus-serialized outputs, same wire shape as `AllocateMiningJobToken.Success.coinbase_tx_outputs`). The sum of amounts MUST satisfy `Σ amount[i] ≤ pool_revenue`. Its serialized size MUST NOT exceed the coinbase output space the JDC reserved for this token (derived from `AllocateMiningJobToken.Success.coinbase_tx_outputs`, §7.1); the JDS uses `coinbase-size-budget-exceeded` if it cannot satisfy this (see §4.3). |

### 2.3 `RequestCoinbaseOutputs.Error` (JDS → JDC)

Sent by the JDS in response to a `RequestCoinbaseOutputs` it cannot or will not serve.

| Field Name    | Data Type | Description                                            |
|---------------|-----------|--------------------------------------------------------|
| `request_id`  | U32       | Echoed from `RequestCoinbaseOutputs`.                  |
| `error_code`  | STR0_255  | Error code (see below).                                |

Defined error codes:

- `invalid-mining-job-token` — the token is unknown or has expired.
- `stale-prev-hash` — the JDS's current view of the chain tip is strictly newer than `prev_hash`, and the pool's payout state for that prev_hash has already been distributed in a more recent block. The JDC MUST refresh its template view before re-requesting.
- `revenue-too-large` — `pool_revenue` exceeds what the JDS considers plausible for any current template (e.g., far above subsidy + observed mempool fees). Anti-fraud safeguard.
- `coinbase-size-budget-exceeded` — the output set the JDS must emit does not fit within the coinbase output space the JDC reserved for this token (derived from `AllocateMiningJobToken.Success.coinbase_tx_outputs`). The JDS avoids this by sizing that field for its worst-case per-job set (§4.3), so the error should be rare; it occurs only when the pool's required size has grown past what the current token reserved. On receipt the JDC MUST obtain a new token (whose `coinbase_tx_outputs` reflects the larger size), re-reserve via `CoinbaseOutputConstraints`, obtain a fresh template, and re-request. See §4.3.
- `internal` — transient JDS-side error. The JDC MAY retry after a short backoff.

Receipt of `RequestCoinbaseOutputs.Error` does not terminate the JDP connection. The JDC MAY retry, fall back to `AllocateMiningJobToken.Success.coinbase_tx_outputs` (§3.4), or switch pools per §6.2.

### 2.4 Message Types

| Message Type (8-bit) | `channel_msg` bit | Message Name                       |
|----------------------|-------------------|------------------------------------|
| `0x00`               | 0                 | `RequestCoinbaseOutputs`           |
| `0x01`               | 0                 | `RequestCoinbaseOutputs.Success`   |
| `0x02`               | 0                 | `RequestCoinbaseOutputs.Error`     |

All messages defined by this extension MUST have `extension_type = 0x0003` in their message frame headers per [Section 3.4.1](../03-Protocol-Overview.md#341-extension-type-field-usage).

---

## 3. Operational Semantics

### 3.1 When the JDC requests

The JDC MUST send a `RequestCoinbaseOutputs` and use the resulting outputs in the next declared job under the following conditions:

- **Initial declaration.** Before the first declared job following `AllocateMiningJobToken.Success`, no prior response exists. The JDC MUST request.
- **`prev_hash` transition.** When the JDC's template provider delivers a template whose `prev_hash` differs from the `prev_hash` of the most recently issued response, the pool's PPLNS-window state has progressed to a new payout epoch. The previously cached response would, if used, redistribute revenue that the pool's accounting has already attributed to the prior block. The JDC MUST refresh.

Beyond those two conditions, the JDC MAY refresh:

- **Fee drift on the same `prev_hash`.** If the template's `template_revenue` has grown materially since the last response and the JDC wishes to declare a job with a more accurate revenue figure, the JDC MAY re-request. The pool's distribution may shift between dust-suppressed and dust-payable for some miners.
- **Implementation policy.** Periodic refresh (e.g., every N seconds while mining on the same `prev_hash`) is permitted but not required. Stale responses on the same `prev_hash` remain valid for declaration: shares that arrived between the response and the declaration roll forward into the next payout window as in any sliding-window PPLNS scheme.

### 3.2 Predictive prefetch

To hide the request/response round-trip at `prev_hash` transitions, the JDC MAY proactively `RequestCoinbaseOutputs` for a predicted next `prev_hash` before the JDC's own template provider observes the new block. The JDC SHOULD treat the prefetched response as conditionally valid: if the actual next `prev_hash` differs from the prediction, the prefetched response MUST be discarded and a fresh request issued.

The JDS MAY rate-limit prefetched requests if it considers the JDC's prefetch policy abusive.

### 3.3 What the JDS computes

On receipt of `RequestCoinbaseOutputs`, the JDS SHOULD:

1. Validate the `mining_job_token` against its current session state.
2. Compare `prev_hash` against its current chain-tip view. If the JDS has already accounted a more recent block for that PPLNS window, return `stale-prev-hash`.
3. Validate `pool_revenue` against current template plausibility (subsidy + observed mempool fees, plus a tolerance). Reject implausible values with `revenue-too-large`.
4. Compute the output list according to its current internal payout state and policy. The computation is implementation-defined and is not constrained by this specification beyond `Σ amount[i] ≤ pool_revenue` and the coinbase-size budget.
5. Cache the emitted response keyed by `(mining_job_token, request_id)` for the duration of the validation window (see §3.5).
6. Return `RequestCoinbaseOutputs.Success`.

The JDS MUST NOT block waiting for its own template provider before responding; the response is a function of pool-internal state and the JDC-reported revenue only.

### 3.4 Fallback

If the JDC has no usable prior response (initial connection, every prior response returned an error, JDS unreachable beyond a JDC-defined timeout), the JDC MAY declare a job using the outputs from `AllocateMiningJobToken.Success.coinbase_tx_outputs` under the existing single-output rule of §6.4.3. This preserves availability when the extension is negotiated but the per-job request path is temporarily disrupted.

The JDS and Pool MUST accept declared jobs that follow the §6.4.3 single-output fallback rule even when this extension is negotiated, so long as the declared coinbase satisfies §6.4.3.

### 3.5 Validation

When the validating party (JDS in Full-Template mode, Pool in Coinbase-only mode) receives a declared job, it MUST verify that the declared coinbase pool outputs match a recently emitted `RequestCoinbaseOutputs.Success` for the same token, or alternatively satisfy the §6.4.3 single-output fallback.

The matching procedure is:

1. Extract the pool-attributable outputs from `DeclareMiningJob.coinbase_tx_suffix` or `SetCustomMiningJob.coinbase_tx_outputs`. These are the outputs whose locking scripts match scripts the JDS emitted in any `RequestCoinbaseOutputs.Success` for this token within the validation window.
2. Verify that the multiset `{(script, amount)}` extracted in (1) equals the multiset emitted in some prior `RequestCoinbaseOutputs.Success` for this token. Order is irrelevant per §6.4.3.

The validating party MAY retain responses for any window it considers safe; one chain-tip's worth of `prev_hash` transitions is a reasonable lower bound.

### 3.6 Race conditions

This section enumerates the two relevant races and their resolution.

**Race A — concurrent block found by a different miner during JDC's mining attempt.** The JDC's TP eventually observes the new tip; the next `prev_hash` transition triggers a refresh (§3.1). The in-flight declared job, if not yet mined to a solution, is naturally abandoned by the JDC moving to the new template. If the JDC mines a solution under the now-orphaned `prev_hash`, the block will be rejected by Bitcoin consensus regardless of coinbase validity.

**Race B — JDS's chain-tip view lags the JDC's view.** The JDC requests for `prev_hash = B` while the JDS still views `prev_hash = A`. The JDS MAY respond optimistically (its PPLNS-window state at A is also valid at B if no block was found between) or MAY return `stale-prev-hash` if it is confident A is not yet superseded. The JDC, on receiving `stale-prev-hash`, waits for either its TP to retract (rare) or the JDS to catch up (common) and retries.

---

## 4. Interaction With §6.4.3

### 4.1 The JDC's freedoms under §6.4.3 remain intact

This extension does not alter any of the JDC's existing freedoms under §6.4.3:

- The JDC MAY reorder pool outputs in `DeclareMiningJob.coinbase_tx_suffix` and `SetCustomMiningJob.coinbase_tx_outputs`. The validating party matches by `{(script, amount)}` multiset, not by position.
- The JDC MAY add additional zero-value outputs.
- The JDC MAY add additional non-zero outputs that allocate revenue to itself. In that case the JDC subtracts those amounts from the `pool_revenue` it reports in `RequestCoinbaseOutputs`, so that `pool_revenue + Σ jdc_self_amounts = template_revenue`. The pool's emitted distribution is sized exactly to `pool_revenue`.

### 4.2 The "first output reserved" requirement

§6.4.3 reserves the first output of `AllocateMiningJobToken.Success.coinbase_tx_outputs` as the pool payout output. When this extension is negotiated, that reservation is satisfied structurally by the contents of `AllocateMiningJobToken.Success.coinbase_tx_outputs`, which MAY be empty or carry a fallback single-output distribution (see §3.4). The per-job output list issued via `RequestCoinbaseOutputs.Success` is independent of position.

### 4.3 Coinbase output reservation

A JDC must tell its Template Provider how many additional coinbase bytes to reserve (`CoinbaseOutputConstraints.coinbase_output_max_additional_size`) **before** it receives a template — the reservation is baked into the template, while the per-job `RequestCoinbaseOutputs` exchange happens afterwards. The JDC therefore cannot, on its own, predict how large a future pool output set will be. This extension does **not** add a new size-negotiation channel; it relies on the one base JDP already defines:

- **The size travels with the token.** Per §7.1, the JDC derives `coinbase_output_max_additional_size` from the serialized size of `AllocateMiningJobToken.Success.coinbase_tx_outputs` and sends it to its Template Provider. The per-job `RequestCoinbaseOutputs.Success` set MUST fit within that reserved size.
- **The token already carries the size — no dummy padding is required.** The JDS computes the token's `coinbase_tx_outputs` from its current payout state at the maximum plausible revenue (full subsidy + fees, the ceiling of any per-job `pool_revenue`). At that revenue the fewest outputs are dust-suppressed, so the committed set is already the largest a per-job response will produce for the same set of recipients; the JDC's reservation therefore covers the full per-job revenue range with no extra work.
- **Growth across recipients is handled per-token.** If the set of *recipients* grows during a token's life (new participants enter the payout window, or an operator/autoscaler raises the coinbase weight budget) a per-job set may exceed what the token reserved. The JDS then returns `coinbase-size-budget-exceeded` and reflects the larger size in the next `AllocateMiningJobToken.Success.coinbase_tx_outputs`; the JDC re-reserves and re-templates on its normal token cadence (typically at least once per `prev_hash` transition). Within a token the per-job output set — both recipients and amounts — is fully dynamic up to the reserved size.
- **Optional growth headroom (operator policy).** To avoid those `coinbase-size-budget-exceeded` round-trips, a JDS MAY pad `AllocateMiningJobToken.Success.coinbase_tx_outputs` with `0`-value outputs (§6.4.3 permits this; "prefer the maximum of all such output sizes") so the reservation already covers anticipated recipient growth. This trades reserved-but-unused block space for fewer token re-issuances; a JDS that does not pad simply re-issues a larger token when the set grows. The spec only requires that every emitted `RequestCoinbaseOutputs.Success.coinbase_tx_outputs` fit the size the current token reserved.

If, at request time, the JDS must emit a set that does not fit the size reserved by the request's token, it MUST return `coinbase-size-budget-exceeded` (§2.3) rather than emit an unusable set or silently truncate. The JDC then obtains a new token reflecting the larger size, re-reserves, re-templates, and re-requests.

---

## 5. Implementation Notes

### 5.1 Bandwidth

`RequestCoinbaseOutputs` is approximately 50 bytes (header + token + prev_hash + revenue). `RequestCoinbaseOutputs.Success` is dominated by `coinbase_tx_outputs`, which is the same wire shape as the existing field on `AllocateMiningJobToken.Success`. A 100-output P2WPKH distribution is approximately 3 100 bytes.

At one request per `prev_hash` transition (~144 per day) plus a few intra-block refreshes, the steady-state bandwidth per JDC is on the order of one MB per day. This is negligible relative to the share-submission traffic on the Mining Protocol connection.

### 5.2 Latency

The JDS's response is computed from pool-internal state and the JDC-reported `pool_revenue`. It does not require the JDS to query its template provider or its underlying Bitcoin node. Typical implementations are expected to respond in single-digit milliseconds. The cost is dominated by serialization of the output list.

The dominant latency cost on the JDC's critical path is the `prev_hash` transition: from the moment the JDC's TP observes a new tip to the moment the JDC can declare a job, the request/response round-trip is unavoidable unless the JDC has prefetched (§3.2).

### 5.3 Privacy

Per-output payout splits expose the pool's internal share-window composition to the JDC operator at request time. This is identical in nature to the existing visibility of `AllocateMiningJobToken.Success.coinbase_tx_outputs`, only on a per-job rather than per-token basis. Pools that wish to keep per-miner attribution private to themselves are not addressed by this extension; the entire mode of operation (multi-output pool payouts in the coinbase) is incompatible with that goal.

### 5.4 JDS↔Pool coordination

In Coinbase-only mode the JDS issues outputs, but the validating party for the declared coinbase is the Pool (the JDC sends `SetCustomMiningJob` directly to the Pool, not to the JDS). This requires the JDS and Pool to share state regarding emitted responses. The mechanism is implementation-defined and identical in nature to the existing JDS↔Pool coordination for `AllocateMiningJobToken.Success.coinbase_tx_outputs`.

### 5.5 Out of scope

The following are out of scope for this extension and are deferred to follow-up extensions or operator policy:

- **Trustless share attestation** between JDC and JDS. The JDC trusts the JDS's emitted distribution, and the JDS trusts the JDC's reported `pool_revenue`. The existing JDP defenses (fallback, share-rejection penalties, optional Zero-Knowledge-Proof extensions) apply.
- **Fee-vs-subsidy split policy.** Pools that wish to pay miners different proportions of fees vs. subsidy do so by adjusting the per-miner amounts in their emitted output list, internally. The wire format does not need to distinguish.
- **Per-output revenue caps, dust thresholds, pending-balance ledgers, payout consolidation cadence.** These are operator policy. The JDS emits the result; how that result was computed is the operator's concern.
- **Push-based updates from JDS to JDC.** All exchanges in this extension are JDC-initiated. Coinbase output reservation reuses the base-JDP channel (the size of `AllocateMiningJobToken.Success.coinbase_tx_outputs`, §4.3), so no JDS-initiated message is introduced. A future extension MAY add a JDS-initiated invalidation or reservation-push message if operational experience shows the per-token reservation cadence is too coarse.
