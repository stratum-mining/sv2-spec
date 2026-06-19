# Stratum V2 Extension: Non-Custodial Pool Payouts

## 0. Abstract

This document defines a Job Declaration Protocol extension that enables non-custodial pooled mining payouts.

The base Job Declaration Protocol supports the common pooled mining model where the block reward is paid to outputs controlled by the pool operator, and miners are subsequently paid by the pool according to the pool's payout policy.

Some non-custodial payout systems instead distribute rewards directly from the coinbase transaction. In such systems, the final coinbase transaction outputs may depend on information that is only available after a mining job token is allocated, such as the amount of value allocated to pool payouts and the pool's accounting state at that time.

This extension defines a mechanism that allows a Job Declaration Client (JDC) to obtain the coinbase transaction outputs required for such non-custodial payouts from a Job Declaration Server (JDS).

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Negotiation

| Extension Type | Extension Name             |
| -------------- | -------------------------- |
| 0x0003         | Non-Custodial Pool Payouts |

When this extension is negotiated, the JDC MAY request payout outputs from the JDS using the messages defined below.

---

## 2. Messages Defined by This Extension

### 2.1 `RequestPayoutOutputs` (JDC -> JDS)

Requests the payout outputs associated with a mining job token.

| Field Name             | Data Type | Description                                                                 |
| ---------------------- | --------- | --------------------------------------------------------------------------- |
| request_id             | U32       | Request identifier.                                                         |
| mining_job_token       | B0_255    | Token previously issued by `AllocateMiningJobToken.Success`.                |
| available_payout_value | U64       | Amount, in satoshis, that MUST be distributed by the returned output set. |

### 2.2 `RequestPayoutOutputs.Success` (JDS -> JDC)

Returned when the JDS successfully computes an output set.

| Field Name            | Data Type | Description                                          |
| --------------------- | --------- | ---------------------------------------------------- |
| request_id            | U32       | Echoed from the request.                             |
| coinbase_tx_outputs   | B0_64K    | Payout outputs to include in the coinbase transaction. |

`coinbase_tx_outputs` uses the same encoding as `SetCustomMiningJob.coinbase_tx_outputs`: a Bitcoin transaction output vector, encoded as a CompactSize output count followed by that many consensus-serialized outputs.

The sum of output amounts in `coinbase_tx_outputs` MUST equal the requested `available_payout_value`.

Any rounding, dust-threshold, or payout-policy residual MUST be represented in `coinbase_tx_outputs`, so that the returned output set sums exactly to `available_payout_value`. This extension does not define how residual value is assigned; the JDS assigns it according to its payout policy.

The serialized size of `coinbase_tx_outputs` MUST NOT exceed the coinbase output reservation associated with the corresponding `mining_job_token`.

### 2.3 `RequestPayoutOutputs.Error` (JDS -> JDC)

Returned when the JDS cannot provide an output set.

| Field Name   | Data Type  | Description              |
| ------------ | ---------- | ------------------------ |
| request_id   | U32        | Echoed from the request. |
| error_code   | STR0_255   | Error identifier.        |

If the JDS cannot construct an output set that both sums to the requested `available_payout_value` and fits within the coinbase output reservation associated with the corresponding `mining_job_token`, it MUST return `RequestPayoutOutputs.Error`.

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name                   |
| -------------------- | --------------- | ------------------------------ |
| 0x00                 | 0               | RequestPayoutOutputs           |
| 0x01                 | 0               | RequestPayoutOutputs.Success   |
| 0x02                 | 0               | RequestPayoutOutputs.Error     |

**Note on Message Framing:** All messages defined by this extension MUST have `extension_type = 0x0003` in their message frame headers, as this extension introduced and defined these messages. For more details on `extension_type` field usage, see [Section 3.4.1 Extension Type Field Usage](../03-Protocol-Overview.md#341-extension-type-field-usage) in the Protocol Overview.

---

## 4. Validation Rules

- `AllocateMiningJobToken.Success.coinbase_tx_outputs` continues to define the coinbase output reservation associated with the mining job token, as specified by the base Job Declaration Protocol.
- `RequestPayoutOutputs.Success.coinbase_tx_outputs` provides the payout output set for a job associated with the specified mining job token.
- A `DeclareMiningJob` or `SetCustomMiningJob` using this extension is valid only if its coinbase transaction includes every output returned in the corresponding `RequestPayoutOutputs.Success`.
- Other coinbase outputs remain governed by the base Job Declaration Protocol rules, including outputs added by the JDC and outputs provided by the Template Provider.
- A `RequestPayoutOutputs.Success` response is single-use. The JDC MUST request a fresh payout output set for each custom job it declares: before each `DeclareMiningJob` in Full-Template mode, and before each `SetCustomMiningJob` in Coinbase-only mode. The JDC MUST NOT reuse a payout output set across multiple custom jobs.
- The validating party is the JDS in Full-Template mode and the Pool in Coinbase-only mode. The validating party MUST treat each `RequestPayoutOutputs.Success` as a single-use pending payout output set. It MUST reject the job if the payout output set is unknown or already used.
- The validating party MAY reject a payout output set that is stale or superseded according to its payout-accounting policy.
- When a job is rejected because its payout output set is stale or superseded, the validating party SHOULD use the error code `stale-payout-outputs`. Upon receiving this error, the JDC SHOULD request a fresh payout output set before retrying the job declaration.

Validation is performed over the multiset:

```text
{ (amount, scriptPubKey) }
```

Output ordering MUST NOT affect validation.

A validating party MUST reject a job if any output returned in the corresponding `RequestPayoutOutputs.Success` is missing, modified, or reduced.

---

## 5. Message Flow

In both Job Declaration modes, the payout output set is requested after the JDC has:

- a `mining_job_token` from the JDS
- a `coinbase_tx_value_remaining` from the Template Provider
- a locally computed `available_payout_value`

The JDC determines `available_payout_value` from `coinbase_tx_value_remaining` after accounting for any other coinbase outputs it intends to include.

If the JDS returns `RequestPayoutOutputs.Error`, the JDC cannot build a job using this extension for that token and available payout value.

### 5.1 Payout Output Set Discovery

| Step | Sender -> Receiver | Message or Action | Notes |
| ---- | ------------------ | ----------------- | ----- |
| 1    | JDC -> JDS         | `AllocateMiningJobToken` | Request a token for future custom work. |
| 2    | JDS -> JDC         | `AllocateMiningJobToken.Success` | Returns `mining_job_token` and the coinbase output reservation. |
| 3    | JDC -> TP          | `CoinbaseOutputConstraints` | Reserves enough template space for outputs associated with the token. |
| 4    | TP -> JDC          | `NewTemplate` | Provides `coinbase_tx_value_remaining`. |
| 5    | JDC                | Determine `available_payout_value` | Chooses the value available for payout outputs after accounting for any other coinbase outputs it intends to include. |
| 6    | JDC -> JDS         | `RequestPayoutOutputs` | Sends `mining_job_token` and `available_payout_value`. |
| 7a   | JDS -> JDC         | `RequestPayoutOutputs.Success` | Returns `coinbase_tx_outputs` for the payout set. |
| 7b   | JDS -> JDC         | `RequestPayoutOutputs.Error` | Returned if the JDS cannot provide a valid output set. |

After `RequestPayoutOutputs.Success`, the JDC constructs a coinbase transaction that includes the returned `coinbase_tx_outputs` plus any other outputs permitted by the base Job Declaration Protocol.

### 5.2 Full-Template Mode Completion

| Step | Sender -> Receiver | Message or Action | Notes |
| ---- | ------------------ | ----------------- | ----- |
| 1    | JDC -> JDS         | `DeclareMiningJob` | The declared coinbase outputs include the outputs returned by `RequestPayoutOutputs.Success`. |
| 2    | JDS                | Validate payout outputs | Validation is performed before acknowledging the declared job. |
| 3    | JDS -> JDC         | `DeclareMiningJob.Success` | Acknowledges the job and returns the token to use with the Pool. |
| 4    | JDC -> Pool        | `SetCustomMiningJob` | Notifies the Pool about the custom job. |
| 5    | Pool -> JDC        | `SetCustomMiningJob.Success` or `SetCustomMiningJob.Error` | Confirms whether the Pool accepts the custom job. |

In Full-Template mode, the JDS validates that the coinbase outputs contained in `DeclareMiningJob` include those returned in the corresponding `RequestPayoutOutputs.Success`.

The standard Full-Template `ProvideMissingTransactions` exchange MAY occur between `DeclareMiningJob` and `DeclareMiningJob.Success`, as defined by the base Job Declaration Protocol.

### 5.3 Coinbase-only Mode Completion

| Step | Sender -> Receiver | Message or Action | Notes |
| ---- | ------------------ | ----------------- | ----- |
| 1    | JDC -> Pool        | `SetCustomMiningJob` | The submitted coinbase outputs include the outputs returned by `RequestPayoutOutputs.Success`. |
| 2    | JDS -> Pool, if separate | Validation state | Implementation-defined communication that lets the Pool validate the output set. |
| 3    | Pool               | Validate payout outputs | Validation is performed before acknowledging the custom job. |
| 4    | Pool -> JDC        | `SetCustomMiningJob.Success` or `SetCustomMiningJob.Error` | Confirms whether the Pool accepts the custom job. |

In Coinbase-only mode, the Pool validates that the coinbase outputs contained in `SetCustomMiningJob` include those returned in the corresponding `RequestPayoutOutputs.Success`.

The mechanism used to communicate validation state from the JDS to the Pool is implementation-defined.

---

## 6. Coinbase Output Reservation

This extension does not modify the coinbase output reservation mechanism defined by the base Job Declaration Protocol.

The JDC continues to derive its reservation from `AllocateMiningJobToken.Success.coinbase_tx_outputs`.

The JDS MUST ensure that any output set returned by `RequestPayoutOutputs.Success` fits within the reservation associated with the corresponding mining job token.

Because the final payout output set may only be known later, the JDS MAY reserve an upper bound at token allocation time. The later `RequestPayoutOutputs.Success.coinbase_tx_outputs` MUST fit within this reserved serialized output size.

---

## 7. Security Considerations

This extension does not define payout algorithms or share accounting rules.

The JDC trusts the JDS to compute the coinbase output set according to the pool's payout policy.

Payout proofs, share attestation, and accounting commitments are outside the scope of this extension.
