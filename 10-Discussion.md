# 10. Discussion
## 10.1 Speculative Mining Jobs
TBD Describe how exactly sending of new jobs before the next block is found works. 

## 10.2 Rolling `nTime`
- `nTime `field can be rolled once per second with the following notes:
- Mining proxy must not interpret greater than minimum `nTime` as invalid submission.
- Device MAY roll `nTime` once per second.
- Pool SHOULD accept `nTime` which is within the consensus limits.
- Pool MUST accept `nTime` rolled once per second.

### 10.2.1 Hardware `nTime` rolling
The protocol allows `nTime` rolling in the hardware as long as the hardware can roll the `nTime` field once per second.

Modern bitcoin ASIC miners do/will support `nTime` rolling in hardware because it is the most efficient way to expand hashing space for one hashing core/chip.
The `nTime` field is part of the second SHA256 block so it shares midstates with the nonce.
Rolling `nTime` therefore can be implemented as efficiently as rolling nonce, with lowered communication with a mining chip over its communication channels.
The protocol needs to allow and support this.

## 10.3 Notes
- Legacy mode: update extranonce1, don’t send all the time (send common merkle-root)
- mining on a locally obtained prevhash (server SHOULD queue the work for some time if the miner has faster access to the network).
- Proxying with separated channels helps with merging messages into TCP stream, makes reconnecting more efficient (and done in proxy, not HW), allows to negotiate work for all devices at once.
- Evaluate reaching the design goals.
- Add promise protocol extension support. It is mainly for XMR and ZEC, but can be addressed in generic way already.
  Promise construction can be coin specific, but the general idea holds for all known use cases.

## 10.4 Usage Scenarios
v2 ST - protocol v2 (this), standard channel

v2 EX - protocol v2, extended channel

v1 - original stratum v1 protocol

### 10.4.1 End Device (v2 ST)
Typical scenario for end mining devices, header-only mining.
The device:

- Sets up the connection without enabling extended channels.
- Opens a Standard channel or more (in the future).
- Receives standard jobs with Merkle root provided by the upstream node.
- Submits standard shares.

### 10.4.2 Transparent Proxy (v2 any -> v2 any)
Translation from v2 clients to v2 upstream, without aggregating difficulty.

Transparent proxy (connection aggregation):

- Passes all `OpenChannel` messages from downstream connections to the upstream, with updated `request_id` for unique identification.
- Associates `channel_id` given by `OpenChannel.Success` with the initiating downstream connection.
  All further messages addressed to the `channel_id` from the upstream node are passed only to this connection, with `channel_id` staying stable.

### 10.4.3 Difficulty Aggregating Proxy (v2 any -> v2 EX)
Proxy:
- Translates all standard ...

V1 

(todo difficulty aggregation with info about the devices)


### 10.4.4 Proxy (v1 -> v2)
Translation from v1 clients to v2 upstream. 

The proxy:
- Accept Opens ...


### 10.4.5 Proxy (v2 -> v1)
...


## 10.5 FAQ


### 10.5.1 Why is the protocol binary?
The original stratum protocol uses json, which has very bad ratio between the payload size and the actual information transmitted.
Designing a binary based protocol yields better data efficiency.
Technically, we can use the saved bandwidth for more frequent submits to further reduce the variance in measured hash rate and/or to allow individual machines to submit its work directly instead of using work-splitting mining proxy.

## 10.6 Terminology
- **upstream stratum node**: responsible for providing new mining jobs, information about new prevhash, etc. 
- **downstream stratum node**: consumes mining jobs by physically performing proof-of-work computations or by passing jobs onto further downstream devices.
- **channel ID**: identifies an individual mining device or proxy after the channel has been opened. Upstream endpoints perform job submission 
- **public key**: ...
- **signature**: signature encoded as...(?)
- **BIP320**: this proposal identifies general purpose bits within version field of bitcoin block header. Mining devices use these bits to extend their search space.
- **Merkle root**: the root hash of a Merkle tree which contains the coinbase transaction and the transaction set consisting of all the other transactions in the block.

## 10.7 Open Questions / Issues
- Write more about channel ID being identifier valid for a particular connection only.
  It works only in the namespace of it.
- Refresh sequence diagrams.
- Is it useful to have channel-based reconnect?
  Or is connection-based enough?
- Decide on how to control a single device and allow it to have open multiple channels. 
- Describe precisely scenarios with `SetNewPrevHash` with regards to repeated block height
- Decide on how to manage assignment of message ID's and the size of the message ID space.
  Shall we allow 2 level multiplexing?
  E.g. dedicate an ID to a class of vendor messages, while allowing the vendor to assign custom messages ID’s within the class?
- More information about telemetry data

```
+----------------------------------------------------------------------------------------------------------------------+
|                                                 Hashing Power Information                                            |
+-------------------------+------------------+-------------------------------------------------------------------------+
| Field Name              | Data Type        | Description                                                             |
+-------------------------+------------------+-------------------------------------------------------------------------+
| aggregated_device_count | U32              | Number of aggregated devices on the channel. An end mining device must  |
|                         |                  | send 1. A proxy can send 0 when there are no connections to it yet (in  | 
|                         |                  | aggregating mode) 																										   | 
+-------------------------+------------------+-------------------------------------------------------------------------+
```
