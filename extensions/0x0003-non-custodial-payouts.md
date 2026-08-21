# Stratum V2 Extension: Non-Custodial Payouts

## 0. Abstract

This document defines a Stratum V2 extension enabling non-custodial payouts under the Job Declaration Protocol (JDP): the coinbase transaction of a declared job pays multiple miners of the same Pool directly, according to the Pool's accounting window.

The extension is designed for non-debt accounting methods (e.g.: PPLNS, SLICE, TIDES), where each found block's reward is split proportionally among miners according to the Pool's current accounting window. Pools implementing debt-based methods (e.g.: PPS, FPPS) SHOULD NOT use this extension.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

---

## 1. Motivation

Base JDP cannot support non-custodial payouts due to an ordering constraint:

1. `AllocateMiningJobToken.Success` fixes the coinbase outputs (and thus the space/sigops JDC reserves via `CoinbaseOutputConstraints`).
2. Only then can JDC receive `NewTemplate`, which is when the template revenue `T` becomes known.

A multi-miner payout requires amounts that depend on `T`, so the outputs cannot be fixed in step 1. This extension resolves the paradox by having JDS publish a **weight-based payout distribution**: outputs and relative weights are known upfront (fixing space/sigops), while absolute amounts are computed deterministically once `T` is known.

---

## 2. Negotiation

The extension is negotiated via [`RequestExtensions`](./0x0001-extensions-negotiation.md) (extension `0x0001`) with extension identifier `0x0003`.

JDC MUST negotiate this extension on **both** the Job Declaration Protocol (JDP) connection with JDS and the Mining Protocol (MP) connection with Pool. If negotiation succeeds on only one connection, JDC MUST NOT use this extension, and Pool/JDS MUST reject any job declaration carrying this extension's TLV fields from such a client.

When negotiated:

- `AllocateMiningJobToken.Success.coinbase_tx_outputs` MUST be empty. All rules of [JDP §6.4.3](../06-Job-Declaration-Protocol.md#643-allocateminingjobtokensuccess-server---client) regarding `coinbase_tx_outputs` (pool payout output, output ordering, JDC-added outputs) are overridden by this extension.
- JDC MUST NOT send `CoinbaseOutputConstraints` to the Template Provider before receiving the first `SetPayoutDistribution` (overriding [TDP §7](../07-Template-Distribution-Protocol.md#7-template-distribution-protocol)'s requirement to send it immediately after the handshake). If no `SetPayoutDistribution` arrives within a reasonable time, JDC SHOULD apply the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).

The extension applies to both Coinbase-only and Full-Template modes.

---

## 3. Messages Defined by This Extension

### 3.1 `SetPayoutDistribution` (JDS -> JDC)

MUST be the first message JDS sends after `SetupConnection.Success` and `RequestExtensions.Success`. JDS sends a new `SetPayoutDistribution` (with incremented `distribution_id`) when the Pool updates the payout distribution (see [§3.1.1](#311-update-policy)).

| Field Name          | Data Type        | Description                                                                                                |
| ------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------- |
| distribution_id     | U64              | Strictly increasing identifier, universal across all Pool/JDS connections of this Pool.                   |
| pool_payout         | B0_64K           | Consensus-serialized tx output. Locking script MUST be controlled by Pool. Amount field MUST be non-0 and encodes `weight_P`, a relative weight (not satoshis). |
| payouts             | SEQ0_64K[B0_64K] | Consensus-serialized tx outputs for miners. Amount fields MUST be non-0 and encode relative weights `weight[i]` (not satoshis). |
| dust_limits         | SEQ0_64K[U32]    | `dust_limits[i]` (satoshis) for each `payouts[i]`. MUST have the same length as `payouts`.                        |
| additional_outputs  | SEQ0_64K[B0_64K] | Consensus-serialized tx outputs added by Pool (e.g. `OP_RETURN`). Amount fields MUST be 0.                 |

`weight_P` is not necessarily just the Pool's fee. Besides the Pool's own share, it MAY include value credited on behalf of miners that are not represented in `payouts` — for example because their pending earnings are below the Pool's payout threshold, because the Pool limits the number of payout outputs in the coinbase, or because of any similar pool policy. Value earned by such miners is paid into the Pool's output; how the Pool tracks it, and how those miners are eventually included in a future distribution, is pool policy and out of scope for this extension.

#### 3.1.1 Update Policy

Share-based accounting methods shift weights with every submitted share. JDS MUST NOT publish a new `SetPayoutDistribution` per share; it SHOULD only publish periodically (e.g. on a timer, or when weights change materially).

The interval length is a pool-tunable tradeoff: shorter intervals reduce the distribution-shopping option value under the optional grace window ([§9.1](#91-distribution-shopping)); longer intervals reduce job rollover overhead.

---

## 4. Payout Computation

Upon receiving a `NewTemplate`, JDC builds the coinbase tx outputs based on the latest `SetPayoutDistribution` it received, subject to the update rule below.

Upon receiving a new `SetPayoutDistribution`, JDC MUST use it as the basis for all subsequently declared jobs. The only exception is the constraint transition of [§5](#5-coinbaseoutputconstraints): while waiting for a `NewTemplate` honoring updated constraints, JDC keeps declaring under the previous distribution.

Variables:

| Variable         | Source                                    | Meaning                                            |
| ---------------- | ----------------------------------------- | -------------------------------------------------- |
| `T`              | `NewTemplate.coinbase_tx_value_remaining` | total template revenue (satoshis)                  |
| `dust_limits[i]` | `SetPayoutDistribution.dust_limits`       | dust limit for miner `i` (satoshis)                |
| `weight[i]`      | `SetPayoutDistribution.payouts`           | relative weight for miner `i`                      |
| `weight_P`       | `SetPayoutDistribution.pool_payout`       | relative weight for pool-controlled address        |
| `W`              | `weight_P + Σ weight[i]`                  | sum total of all weights                           |
| `amount[i]`      | computed                                  | miner `i` proportional amount, before dust pruning |
| `amount_P`       | computed                                  | pool proportional amount                           |
| `pay[i]`         | computed                                  | final miner `i` payout (satoshis); no output if `amount[i] < dust_limits[i]` (dust-pruned) |
| `pay_P`          | computed                                  | final Pool payout (satoshis); absorbs integer rounding and dust pruning   |

Formulae:

```
W         = weight_P + Σ weight[i]
amount_P  = floor(weight_P · T / W)
amount[i] = floor(weight[i] · T / W)
pay[i]    = if amount[i] ≥ dust_limits[i] { amount[i] } else { dust-pruned }
pay_P     = T − Σ pay[i]
```

There's no `dust_limit` corresponding to `pool_payout`, therefore `pay_P` MUST NOT be dust-pruned.

`pay_P` therefore aggregates three components:

1. the Pool's own share, via `weight_P`;
2. value credited on behalf of miners not represented in `payouts` (see [§3.1](#31-setpayoutdistribution-jds---jdc)), also via `weight_P`;
3. dust-pruned amounts and integer rounding remainders, absorbed at payout-computation time.

Components 2 and 3 are miner-earned value that could not be paid on-chain in this block.

Intermediate arithmetic MUST use at least 128-bit integers to avoid potential overflows (`weight · T` can reach ~2^115, `W` can reach ~2^80).

Coinbase tx output ordering MUST be exactly:

1. `pool_payout` with amount `pay_P`
2. `payouts`, in distribution order, with amounts `pay[i]` (output omitted if dust-pruned)
3. `additional_outputs` (if any, in distribution order, amounts MUST be 0)
4. JDC-appended outputs (if any, amounts MUST be 0)
5. TP-appended outputs (amounts MUST be 0, witness commitment MUST be last)

JDC MUST NOT reorder outputs, and MUST NOT arbitrarily add non-0 value outputs.

---

## 5. CoinbaseOutputConstraints

JDC computes `coinbase_output_max_additional_size` and `coinbase_output_max_additional_sigops` from the latest `SetPayoutDistribution` (`pool_payout` + `payouts` + `additional_outputs`), including:
- outputs that might get pruned as dust per [§4](#4-payout-computation)
- 0-valued outputs that JDC wishes to include

If a new `SetPayoutDistribution` changes these constraints, JDC MUST send a new `CoinbaseOutputConstraints` to TP.

Until TP sends a `NewTemplate` honoring new constraints, JDC SHOULD keep declaring under the previous distribution (see [§7.2](#72-grace-window) grace window).

If constraints stay the same, even after a new `SetPayoutDistribution`, JDC SHOULD NOT send a new `CoinbaseOutputConstraints` to TP.

If the computed constraints violate Bitcoin-consensus blockspace or sigops budget, JDC SHOULD apply the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).

---

## 6. `distribution_id` TLV Field

This extension defines the following TLV field, allowing JDS/Pool to match a job declaration against the corresponding `SetPayoutDistribution`:

| Field            | Size    | Description                                                                                              |
| ---------------- | ------- | -------------------------------------------------------------------------------------------------------- |
| Type (U16 \| U8) | 3 bytes | Extension Type (U16): `0x0003`; Field Type (U8): `0x01` (`distribution_id`)                              |
| Length (U16)     | 2 bytes | MUST be `0x0008`                                                                                         |
| Value            | 8 bytes | `distribution_id` (U64) of the `SetPayoutDistribution` this job was built from                            |

When this extension is negotiated, JDC MUST append this TLV field to the following message, depending on the Job Declaration mode:

| Mode           | Message                                 |
| -------------- | --------------------------------------- |
| Full-Template  | `DeclareMiningJob`                      |
| Coinbase-only  | `SetCustomMiningJob`                    |

---

## 7. Validation

### 7.1 Output Verification

Validation is recompute-and-compare: the verifier recomputes the expected output vector from (`SetPayoutDistribution`, `T`) per [§4](#4-payout-computation) and compares it against the declared coinbase, allowing only JDC-appended 0-value outputs in position 4.

### 7.2 Grace Window

JDS/Pool MAY accept declarations matching the distribution immediately before the current one (a grace window). This absorbs honest races — declarations already in flight when a new distribution is published — at the cost of one-window optionality for miners ([§9.1](#91-distribution-shopping)). Any declaration not covered by the acceptance window MUST be rejected with the `stale-payout-distribution` error code.

### 7.3 Error Codes

This extension defines the following `error_code` values for `DeclareMiningJob.Error` and `SetCustomMiningJob.Error`:

| error_code                  | Description                                                              |
| --------------------------- | ------------------------------------------------------------------------ |
| `stale-payout-distribution`        | `distribution_id` not accepted (too old, or invalidated by settlement — see [§10](#10-implementation-notes)). |
| `invalid-payout-distribution` | Coinbase outputs violate [§4](#4-payout-computation).                                  |

Responses carrying `stale-payout-distribution` SHOULD NOT trigger the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client) — they cover honest races (in-flight declarations). This exemption is not unconditional: an honest race resolves once JDC re-declares against the latest received distribution, so JDC SHOULD treat persistent `stale-payout-distribution` rejections of declarations built on the latest received distribution as it would any other rejection, and apply the fallback strategy of [JDP §6.2](../06-Job-Declaration-Protocol.md#62-job-declarator-client).

---

## 8. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name           |
| -------------------- | --------------- | ---------------------- |
| 0x00                 | 0               | SetPayoutDistribution  |

**Message Framing:** `SetPayoutDistribution` MUST have `extension_type = 0x0003` in its frame header. `DeclareMiningJob` and `SetCustomMiningJob` keep `extension_type = 0x0000` (modified via TLV only). See [§3.4.1 of the Protocol Overview](../03-Protocol-Overview.md#341-extension-type-field-usage).

---

## 9. Security Considerations

### 9.1 Distribution Shopping

If JDS implements the grace window ([§7.2](#72-grace-window)), a JDC holding distributions `k-1` and `k` can choose whichever pays it more (a violation of the [§4](#4-payout-computation) update rule, but indistinguishable from honest races on the wire). This is bounded to one window: the Pool settles per the `distribution_id` of the winning declaration, and a sufficiently short update interval ([§3.1.1](#311-update-policy)) keeps the option value small.

### 9.2 Privacy

The distribution is pool-wide: every JDC learns the payout scripts and relative weights of the Pool's top miners. Pools SHOULD weigh this leak when choosing the number of payout slots.

### 9.3 Trust Model

The Pool still dictates scripts and weights, so custodial trust assumptions are unchanged. However, miners included in the distribution gain coinbase-level verifiability of their payout, and dust-pruned/rounded amounts are auditable (they flow to `pay_P` by construction).

Value that cannot be paid on-chain — whether credited into `weight_P` when the distribution is built (miners below the Pool's payout threshold, output-count caps, or similar policies) or absorbed by `pay_P` at payout-computation time (dust pruning, integer rounding) — is held by the Pool. For this value, the trust assumptions are the same as under custodial payouts: whether and how it is credited back to the affected miners is pool accounting policy, outside the scope of this extension. As a mitigation, the composition of `pay_P` is fully computable by any JDC holding the distribution, so the held amounts are auditable to the satoshi.

---

## 10. Implementation Notes

Pool and JDS are assumed to share state.

**Settlement invalidation**: when the Pool finds a block, it settles its accounting per the `distribution_id` of the winning declaration. Pool/JDS SHOULD atomically invalidate all other distributions and publish a fresh `SetPayoutDistribution`; Pool/JDS SHOULD only accept job declarations based on this new distribution, until the next one is published (the grace window of [§7.2](#72-grace-window) SHOULD NOT span a settlement event). This prevents *new* declarations from paying an already-settled window twice. It cannot, however, prevent a block being found on a job already declared and accepted before settlement: such a block pays the settled distribution again, and since payouts are non-custodial, this cannot be corrected after the fact. How this risk is absorbed is pool accounting policy, out of scope for this extension. Declarations rejected due to settlement invalidation carry `stale-payout-distribution` and are honest races ([§7.3](#73-error-codes)).
