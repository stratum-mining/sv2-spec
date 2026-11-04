# Stratum V2 Extension: Requested Payout Outputs

## 0. Abstract

This document defines a Job Declaration Protocol extension for pools that pay miners directly from the coinbase, and whose coinbase outputs depend on the template being mined.

In some non-custodial payout systems, the coinbase outputs are not a function of a payout distribution alone. They also depend on the template: its height, its previous block hash, its target, the coinbase revenue, and the coinbase scriptSig the client will use. A share chain, for example, may commit to the previous share and to the client's scriptSig in the coinbase, and every node may rebuild each coinbase and reject a share whose outputs differ. A payout distribution published ahead of time cannot express such outputs.

This extension lets a Job Declaration Client (JDC) send the JDS the template inputs the outputs depend on, and receive the exact output set in return. Its messages follow the request/response design of `RequestPayoutOutputs` (sv2-spec PR #202), adding:

- the template fields;
- an exact-placement flag;
- the required coinbase version, input sequence and lock time;
- a message that tells the JDC when its output sets become stale.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Negotiation

| Extension Type | Extension Name            |
| -------------- | ------------------------- |
| 0x0004         | Requested Payout Outputs  |

The JDC requests this extension with `RequestExtensions` (see [Extensions Negotiation](./0x0001-extensions-negotiation.md)) on its Job Declaration connection, in both Coinbase-only and Full-Template modes.

The Mining Protocol connection is unchanged. The custom job is a standard `SetCustomMiningJob`.

When this extension is negotiated:
- the JDC MAY request payout outputs from the JDS using the messages defined below;
- the JDS MAY send `PayoutOutputsStale`.

---

## 2. Messages Defined by This Extension

### 2.1 `RequestPayoutOutputs` (JDC -> JDS)

Requests the payout outputs for a job the JDC is about to declare, on a mining job token.

| Field Name             | Data Type | Description                                                                                       |
| ---------------------- | --------- | ------------------------------------------------------------------------------------------------- |
| request_id             | U32       | Request identifier.                                                                               |
| mining_job_token       | B0_255    | Token previously issued by `AllocateMiningJobToken.Success`.                                      |
| available_payout_value | U64       | Amount, in satoshis, that MUST be distributed by the returned output set.                         |
| height                 | U32       | Height of the block the template builds.                                                          |
| prev_hash              | U256      | Previous block hash of the template.                                                              |
| nbits                  | U32       | Compact target of the template.                                                                   |
| coinbase_prefix        | B0_255    | The coinbase input's scriptSig bytes before the extranonce, exactly as the job will declare them. |

### 2.2 `RequestPayoutOutputs.Success` (JDS -> JDC)

Returned when the JDS successfully computes an output set.

| Field Name                  | Data Type | Description                                                                      |
| --------------------------- | --------- | -------------------------------------------------------------------------------- |
| request_id                  | U32       | Echoed from the request.                                                         |
| flags                       | U32       | Bit 0: `EXACT_OUTPUTS` (see [Section 4](#4-validation-rules)). Other bits MUST be 0. |
| coinbase_tx_version         | U32       | The coinbase transaction version the job MUST use when `EXACT_OUTPUTS` is set.   |
| coinbase_tx_input_nSequence | U32       | The coinbase input's sequence the job MUST use when `EXACT_OUTPUTS` is set.      |
| coinbase_tx_locktime        | U32       | The coinbase lock time the job MUST use when `EXACT_OUTPUTS` is set.             |
| coinbase_tx_outputs         | B0_64K    | Payout outputs for the coinbase transaction.                                     |

`coinbase_tx_outputs` uses the same encoding as `SetCustomMiningJob.coinbase_tx_outputs`: a Bitcoin transaction output vector, encoded as a CompactSize output count followed by that many consensus-serialized outputs.

The sum of output amounts in `coinbase_tx_outputs` MUST equal the requested `available_payout_value`. Zero-value outputs, such as commitments, MAY be included.

When `EXACT_OUTPUTS` is not set, `coinbase_tx_version`, `coinbase_tx_input_nSequence` and `coinbase_tx_locktime` MUST be 0 and are ignored.

The serialized size of `coinbase_tx_outputs` MUST NOT exceed the coinbase output reservation associated with the corresponding `mining_job_token`.

### 2.3 `RequestPayoutOutputs.Error` (JDS -> JDC)

Returned when the JDS cannot provide an output set.

| Field Name   | Data Type  | Description              |
| ------------ | ---------- | ------------------------ |
| request_id   | U32        | Echoed from the request. |
| error_code   | STR0_255   | Error identifier.        |

Defined error codes:
- `invalid-mining-job-token`: the token is unknown, expired or already used.
- `stale-payout-outputs`: the token or the template no longer matches what the JDS can pay (see [Section 5](#5-staleness)).
- `invalid-request`: a field is malformed or inconsistent, for example a `prev_hash` the JDS does not know.
- `payout-outputs-too-large`: the output set does not fit the reservation associated with the token.
- `payout-outputs-unavailable`: the JDS cannot compute an output set at this time.

### 2.4 `PayoutOutputsStale` (JDS -> JDC)

Tells the JDC that output sets for tokens allocated before this message have become stale. This happens, for example, when the accounting state the outputs depend on has moved.

This message has no fields.

On receiving it, the JDC SHOULD allocate a new token and request a new output set before declaring its next job.

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name                   |
| -------------------- | --------------- | ------------------------------ |
| 0x00                 | 0               | RequestPayoutOutputs           |
| 0x01                 | 0               | RequestPayoutOutputs.Success   |
| 0x02                 | 0               | RequestPayoutOutputs.Error     |
| 0x03                 | 0               | PayoutOutputsStale             |

**Note on Message Framing:** All messages defined by this extension MUST have `extension_type = 0x0004` in their message frame headers, as this extension introduced and defined these messages. For more details on `extension_type` field usage, see [Section 3.4.1 Extension Type Field Usage](../03-Protocol-Overview.md#341-extension-type-field-usage) in the Protocol Overview.

---

## 4. Validation Rules

- **Reservation.** `AllocateMiningJobToken.Success.coinbase_tx_outputs` continues to define the coinbase output reservation for the token, as specified by the base Job Declaration Protocol. The JDS MUST reserve an upper bound that every later output set for that token fits within.
- **Identity.** `AllocateMiningJobToken.user_identifier` identifies whom the outputs pay, in the pool's own format. The token is bound to it.
- **Single use.** A `RequestPayoutOutputs.Success` response is single-use:
  - The JDC MUST request a fresh output set for each custom job it declares: before each `DeclareMiningJob` in Full-Template mode, and before each `SetCustomMiningJob` in Coinbase-only mode.
  - The JDC MUST NOT reuse an output set across custom jobs.
- **Validator.** The validating party is the JDS in Full-Template mode and the Pool in Coinbase-only mode. It MAY recompute the output set from the request rather than store it, and MUST reject a job built on an unknown or already used output set.
- **Ordinary rejections.** A job whose coinbase does not satisfy the rules below is rejected with the base protocol's `DeclareMiningJob.Error` or `SetCustomMiningJob.Error`.

**Without `EXACT_OUTPUTS`:**
- The coinbase transaction MUST include every returned output. Output ordering MUST NOT affect validation, which is performed over the multiset `{ (amount, scriptPubKey) }`.
- Other coinbase outputs remain governed by the base Job Declaration Protocol rules, including outputs added by the JDC and outputs provided by the Template Provider.

**With `EXACT_OUTPUTS`:**
- The coinbase transaction's outputs MUST be exactly the returned outputs, in the returned order. The only exception: on a chain with a witness commitment, the Template Provider's witness commitment output MAY follow them.
- The coinbase transaction MUST use the returned `coinbase_tx_version`, `coinbase_tx_input_nSequence` and `coinbase_tx_locktime`.
- The coinbase input's scriptSig MUST be `coinbase_prefix` followed directly by the extranonce.
- `available_payout_value` MUST equal the template's `coinbase_tx_value_remaining`.
- A JDC whose template requires coinbase outputs of its own, other than a witness commitment, cannot use the output set. It SHOULD apply the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).

`EXACT_OUTPUTS` exists for validators that rebuild the whole coinbase and compare it byte for byte, such as share chains where every node checks every share.

---

## 5. Staleness

The JDS sends `PayoutOutputsStale` when the state its output sets depend on has moved. Output sets for tokens allocated before it are stale.

A request or job on a stale token MAY be refused with `stale-payout-outputs`. This is an honest race, not a refusal: the JDC SHOULD allocate a new token and request again, and SHOULD NOT apply the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client) for it. The exemption is not unconditional: the JDC SHOULD treat persistent `stale-payout-outputs` answers, for tokens allocated after the last `PayoutOutputsStale` it received, as it would any other refusal.

Every other `RequestPayoutOutputs.Error` SHOULD trigger the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).

---

## 6. Message Flow

In both Job Declaration modes, the output set is requested after the JDC has a `mining_job_token` from the JDS and a template from its Template Provider.

| Step | Sender -> Receiver | Message or Action | Notes |
| ---- | ------------------ | ----------------- | ----- |
| 1    | JDC -> JDS         | `AllocateMiningJobToken` | Request a token for future custom work. |
| 2    | JDS -> JDC         | `AllocateMiningJobToken.Success` | Returns `mining_job_token` and the coinbase output reservation. |
| 3    | JDC -> TP          | `CoinbaseOutputConstraints` | Reserves enough template space for the outputs associated with the token. |
| 4    | TP -> JDC          | `NewTemplate`, `SetNewPrevHash` | Provide `coinbase_tx_value_remaining`, height, previous hash and target. |
| 5    | JDC -> JDS         | `RequestPayoutOutputs` | Sends the token, `available_payout_value`, the template fields and `coinbase_prefix`. |
| 6a   | JDS -> JDC         | `RequestPayoutOutputs.Success` | Returns the output set and, with `EXACT_OUTPUTS`, the coinbase version, sequence and lock time. |
| 6b   | JDS -> JDC         | `RequestPayoutOutputs.Error` | Returned if the JDS cannot provide a valid output set. |

The JDC keeps hashing its current job while it waits. It MAY request an output set ahead of time for a template it expects, such as the next block after a predicted `prev_hash`.

Full-Template and Coinbase-only completion are as in the base Job Declaration Protocol:
- **Full-Template:** the JDS validates the outputs in `DeclareMiningJob`, including any `ProvideMissingTransactions` exchange, before `DeclareMiningJob.Success`.
- **Coinbase-only:** the Pool validates the outputs in `SetCustomMiningJob` before `SetCustomMiningJob.Success`. How the JDS shares validation state with a separate Pool is implementation-defined.

---

## 7. Relation to Other Payout Extensions

Coinbase Transaction Payouts (sv2-spec PR #203) publishes a weight-based payout distribution once per accounting window. The JDC computes amounts from it without a round trip.

This extension serves pools whose outputs cannot be written as such a distribution, because they depend on each template or on the client's coinbase. It costs one round trip per declared job.

A JDC MAY implement both. Each extension is negotiated separately.

---

## 8. Security Considerations

- **Payout policy.** This extension does not define payout algorithms or share accounting rules. The JDC trusts the JDS to compute the output set according to the pool's payout policy. Where the policy is a public rule, such as a share chain, anyone holding the pool's state can recompute the answer.
- **Privacy.** The request reveals:
  - the template's height, previous hash and target, which are public;
  - the coinbase scriptSig prefix;
  - `available_payout_value`, which reveals the template's total fees.

  No transaction data is sent, so in Coinbase-only mode the JDS learns nothing of the template's transaction set.
- **Censorship.** The JDS does not choose transactions and cannot change the client's template. It can only answer or refuse. A refusal triggers the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).
- **Resource use.** Each request costs the JDS a payout computation. A JDS MAY rate-limit requests per connection and answer excess requests with `payout-outputs-unavailable`.
