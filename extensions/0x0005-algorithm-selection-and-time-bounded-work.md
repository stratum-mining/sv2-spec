# Stratum V2 Extension: Algorithm Selection and Time-Bounded Work

## 0. Abstract

This extension adds two mechanisms for chains whose proof of work is not a
single time-invariant function.

**Algorithm selection** lets a downstream role state which proof-of-work
algorithm a connection carries, on chains that mine several concurrently with
independent per-algorithm difficulty.

**Time-bounded work** lets an upstream role state an upper bound on `ntime`, for
chains whose hash function depends on a time epoch.

It defines five new messages, changes no existing message and adds no TLV
fields. It applies to both the Template Distribution Protocol and the Mining
Protocol, which need the same two statements for the same reasons.

The algorithm identifier is a chain-defined value. This extension specifies how
an algorithm is selected and acknowledged, not which algorithms exist.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

## 1. Overview

### 1.1 Algorithm Selection

Stratum v2 assumes one proof-of-work function for a chain. A chain mining
several concurrently, each with its own difficulty and proof-of-work limit, has
no way for a downstream role to say which one a connection is for. An upstream
role can then only pin one algorithm per listening port, which is a deployment
constraint standing in for a protocol field.

A downstream role sends `SelectAlgorithm` once per connection. The algorithm is
immutable for the life of the connection, because a connection carries one
difficulty and target stream.

### 1.2 Time-Bounded Work

Stratum v2 bounds `ntime` from below only. `NewMiningJob.ntime_start` is defined
as the `nTime` at which hashing starts, and the specification states that it is
**not** the consensus minimum. No message states a maximum.

For a chain whose hash function is selected by a time epoch, that is a silent
failure. A miner rolling `ntime` across an epoch boundary does not produce a
rejected share: it produces a correct hash of a different function, submitted in
good faith, which is indistinguishable from bad luck at the miner and from an
invalid share at the pool.

An upstream role therefore states both bounds explicitly, as absolute values
rather than as an offset or a mask. Two messages carry the same information
keyed for the two protocols, because `template_id` has no meaning to a worker
and `job_id` has none to a Template Distribution client. Keeping them separate
means an implementation serving both links, such as a pool, cannot confuse a
template id with a job id.

`ntime_min` restates the lower bound rather than deferring to `ntime_start`, and
the restatement is load-bearing: `ntime_start` is where hashing begins and is
explicitly not a rule, whereas `ntime_min` is a bound below which the upstream
role will refuse the submission. The two carry the same number and mean
different things. Carrying both bounds in one message also means an upstream
that computes a window once cannot emit halves that disagree.

### 1.3 Extension Activation (Negotiation Process)

The extension is negotiated through Extensions Negotiation (`0x0001`), after
`SetupConnection.Success` and before any protocol message that depends on it.

1. The downstream role completes `SetupConnection`.
2. It sends `RequestExtensions` listing `0x0005`.
3. On `RequestExtensions.Success` it sends `SelectAlgorithm`, before opening a
   channel on the Mining Protocol, or before requesting a template on Template
   Distribution.
4. On `RequestExtensions.Error` it has not negotiated the extension and MUST NOT
   send any message defined here.

An upstream role MAY list `0x0005` in `required_extensions` and close
connections that do not negotiate it. On a chain where the two failure modes
above are silent, that is the difference between a miner being told and a miner
wasting its work, so implementations are encouraged to require it.

#### Message Exchange Example

```
Downstream -> Upstream:  SetupConnection
Upstream -> Downstream:  SetupConnection.Success
Downstream -> Upstream:  RequestExtensions { request_id, requested_extensions: [0x0005] }
Upstream -> Downstream:  RequestExtensions.Success { request_id, supported_extensions: [0x0005] }
Downstream -> Upstream:  SelectAlgorithm { pow_type }
Upstream -> Downstream:  SelectAlgorithm.Success { pow_type, version_rolling_mask }
```

## 2. Messages Defined by This Extension

All integers are little-endian, as elsewhere in Stratum v2.

### `SelectAlgorithm` (Client -> Server)

| Field Name | Data Type | Description |
| --- | --- | --- |
| `pow_type` | `U8` | The proof-of-work algorithm this connection is for. Values are defined by the chain, not by this extension. |

Sent once per connection. A second `SelectAlgorithm` on one connection MUST be
answered with `SelectAlgorithm.Error` carrying `algo-already-selected`.

### `SelectAlgorithm.Success` (Server -> Client)

| Field Name | Data Type | Description |
| --- | --- | --- |
| `pow_type` | `U8` | The algorithm now bound to this connection. |
| `version_rolling_mask` | `U32` | The bits of the block version the client MAY change. Zero means none. |

`version_rolling_mask` is stated here because a chain that encodes the algorithm
inside the block version cannot leave version rolling to BIP320. BIP320's mask
covers bits 13-28, which can fully contain such a field, and rolling it either
fails a consensus check or silently moves the share to another algorithm and
another proof-of-work limit.

A client MUST NOT change any bit outside this mask. A server that cannot permit
rolling at all sends zero, and SHOULD also set `REQUIRES_FIXED_VERSION` in
`SetupConnection.Success`, which is the enforceable half of the same statement.

### `SelectAlgorithm.Error` (Server -> Client)

| Field Name | Data Type | Description |
| --- | --- | --- |
| `error_code` | `STR0_255` | Why the algorithm was refused. |

Defined values:

| `error_code` | Meaning |
| --- | --- |
| `unsupported-pow-type` | Not an algorithm this chain defines. |
| `pow-type-not-enabled` | An algorithm this chain defines, but not one this server was configured to serve. |
| `algo-already-selected` | A second `SelectAlgorithm` on one connection. |

These values are normative. An extension whose only stated error type is "a
`STR0_255`" cannot be implemented against, and the distinction between the first
two is the difference between "update your software" and "use another port".

### `TemplateTimeConstraints` (Server -> Client)

Template Distribution Protocol.

| Field Name | Data Type | Description |
| --- | --- | --- |
| `template_id` | `U64` | The template these bounds apply to. |
| `ntime_min` | `U32` | Lowest acceptable `ntime`, inclusive. |
| `ntime_max` | `U32` | Highest acceptable `ntime`, inclusive. |

Sent after every `NewTemplate`, including an in-place refresh of a template
already issued. Both bounds are inclusive.

`ntime_min` MUST equal the `ntime_start` the server supplies in `SetNewPrevHash`
for that template, so that a client holding both messages sees one window.

A server MAY re-evaluate any term of `ntime_max` that depends on wall-clock time
when a solution arrives, so that a long-lived template cannot be used to submit
a timestamp the chain would reject by the time it is seen.

### `JobTimeConstraints` (Server -> Client)

Mining Protocol. This is a **channel message**: bit 15 of `extension_type` is
set, so it appears on the wire under `0x8005`. Bit 15 is the `channel_msg` flag
and is ignored when an implementation looks up which extension a message belongs
to.

| Field Name | Data Type | Description |
| --- | --- | --- |
| `channel_id` | `U32` | The channel these bounds apply to. |
| `job_id` | `U32` | The job these bounds apply to. |
| `ntime_min` | `U32` | Lowest acceptable `ntime`, inclusive. |
| `ntime_max` | `U32` | Highest acceptable `ntime`, inclusive. |

Sent for every `NewMiningJob` and `NewExtendedMiningJob`. Both bounds are
inclusive. The ordering is normative, because a worker activated by
`SetNewPrevHash` is required to begin hashing immediately and must never hold an
active job whose `ntime_max` it does not know:

```
active job, ntime_start present
    JobTimeConstraints.ntime_min MUST equal NewMiningJob.ntime_start

future job, ntime_start absent
    the constraints MAY be sent with the job, if the bounds are known then
    otherwise they MUST be sent immediately before the SetNewPrevHash that
    activates the job
    either way, the ntime_start that SetNewPrevHash supplies MUST equal the
    ntime_min in force for that job
```

A client MUST NOT begin hashing a job until it holds both the applicable time
constraints and the activation information.

Where a server holds a job open across a template refresh, it MUST re-send this
message with the new bounds.

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name |
| --- | --- | --- |
| `0x00` | 0 | `SelectAlgorithm` |
| `0x01` | 0 | `SelectAlgorithm.Success` |
| `0x02` | 0 | `SelectAlgorithm.Error` |
| `0x03` | 0 | `TemplateTimeConstraints` |
| `0x04` | 1 | `JobTimeConstraints` |

## 4. Implementation Notes

### 4.1 One identifier across two protocols

The three `SelectAlgorithm` messages are byte-identical on both protocols,
because they are connection-scoped and carry nothing protocol-specific. Only the
time constraints differ, and only in how they key the work.

One identifier rather than two is deliberate. A pool is a Template Distribution
client facing the node and a Mining Protocol server facing its workers. Under
two identifiers it would negotiate two extensions to obtain one capability, and
the same three message definitions would exist twice.

### 4.2 Narrowing a window downstream

A role that is a client on one link and a server on the next, which is what a
pool is, derives the window it issues from the window it received. It MUST
narrow, never widen: the upstream will refuse a solution outside its own window,
and a worker told it has more room than the upstream allows will produce work
that cannot be submitted.

It MUST also not narrow to nothing. On a chain or network that pins the window
shut, `ntime_min` already equals `ntime_max`, and any narrowing leaves a worker
with no legal `ntime`. An empty window is a protocol error, and the job MUST be
refused rather than issued in a form that cannot be worked.

### 4.3 Refusing a client that demands version rolling

The specification states that a server MUST NOT set `REQUIRES_FIXED_VERSION` if
the client set `REQUIRES_VERSION_ROLLING`, which makes the two mutually
exclusive rather than one overriding the other. A server on a chain that encodes
the algorithm in the block version cannot honour rolling at all, so a client
demanding it MUST be refused with `SetupConnection.Error` rather than answered
and then held to a fixed version it did not agree to.

### 4.4 Error codes a server on such a chain needs

Two submission refusals follow from this extension and have no existing code.
Both are refusals the extension exists to make possible, and a client cannot act
on a code it has never been told about:

| `error_code` | Meaning |
| --- | --- |
| `invalid-version` | The submitted version differs from the job's, which `REQUIRES_FIXED_VERSION` forbids and which would move the share to another algorithm's proof-of-work limit. |
| `invalid-ntime` | The submitted `ntime` is outside the window `JobTimeConstraints` gave for that job. |

### 4.5 Forward compatibility within this extension

Message numbers inside an allocated `extension_type` are the extension's own to
assign, so a later message can be added without a new allocation. That holds on
one condition, which implementations MUST observe:

**A receiver MUST ignore a message whose `extension_type` it has negotiated and
whose `msg_type` it does not recognise.** Log it and read the next frame. It
MUST NOT be treated as a protocol violation, and the connection MUST NOT be
closed.

Negotiation agrees an `extension_type`. It says nothing about which message
numbers inside it either side knows, because the two implementations were built
at different times. Without this rule, adding a message is not compatible at
all: it breaks every peer built before it. This is not hypothetical, and the
worked example is in the Block Found Notification extension's section 4.1,
which exists as a separate extension because of it.

Three limits on the rule, because it is narrower than it first looks.

**It licenses optional additions only.** A message a peer can do without may be
ignored safely. A message that changes which work is valid may not: a future
constraint that narrowed a window, silently skipped, would leave a client
producing work the server will refuse, which is the failure this extension
exists to prevent. Such a message needs explicit capability negotiation, and
since the `extension_type` is Stratum v2's only capability granularity, that
means another allocation rather than another `msg_type`.

**It binds the endpoint that receives the message.** A proxy or translating
role forwarding Stratum v2 onward MUST forward what it does not recognise
rather than discard it, or it silently strips capability from the roles behind
it.

**It cannot be retrofitted.** Software already deployed does not acquire the
rule by this document existing. Until peers carry it, a new message has to be
suppressed for peers known not to handle it, or placed behind its own
identifier so they never ask for it.

Changing the layout or meaning of a message number already defined is not
covered by the rule at all, and MUST be treated as a new extension version with
its own identifier.

### 4.6 Reference implementation

Avian implements this extension on both links, with two concurrent algorithms,
X16RT and MinotaurX, and a 128-second X16RT epoch that supplies the time bound.
Its mapping is `pow_type` 0 for X16RT and 1 for MinotaurX, which is an example
of a chain-defined mapping rather than part of this format.

- Implementation: https://github.com/AvianNetwork/Avian/pull/267
