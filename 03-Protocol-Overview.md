# 3. Protocol Overview

There are technically four distinct (sub)protocols needed in order to fully use all of the features proposed in this document:

1. **Mining Protocol**  
   The main protocol used for mining and the direct successor of Stratum v1.
   A mining device uses it to communicate with its upstream node, pool, or a proxy.
   A proxy uses it to communicate with a pool (or another proxy).
   This protocol needs to be implemented in all scenarios.
   For cases in which a miner or pool does not support transaction selection, this is the only protocol used.

2. **Job Declaration Protocol**  
   Used by a miner (a whole mining farm) to declare a block template with a pool.
   Results of this declaration can be re-used for all mining connections to the pool to reduce computational intensity.
   In other words, a single declaration can be used by an entire mining farm or even multiple farms with hundreds of thousands of devices, making it far more efficient.
   This is separate to allow pools to terminate such connections on separate infrastructure from mining protocol connections (i.e. share submissions).
   Further, such connections have very different concerns from share submissions - work declaration likely requires, at a minimum, some spot-checking of work validity, as well as potentially substantial rate-limiting (without the inherent rate-limiting of share difficulty).

3. **Template Distribution Protocol**  
   A similarly-framed protocol for getting information about the next block out of Bitcoin Core.
   Designed to replace `getblocktemplate` with something much more efficient and easy to implement for those implementing other parts of Stratum v2.

4. **Job Distribution Protocol**  
   Simple protocol for passing newly-declared work to interested nodes - either proxies or miners directly.
   This protocol is left to be specified in a future document, as it is often unnecessary due to the Job Declaration role being a part of a larger Mining Protocol Proxy.

Meanwhile, there are five possible roles (types of software/hardware) for communicating with these protocols.

1. **Mining Device**  
   The actual device computing the hashes. This can be further divided into header-only mining devices and standard mining devices, though most devices will likely support both modes.

2. **Pool Service**  
   Produces jobs (for those not declaring jobs via the Job Declaration Protocol), validates shares, and ensures blocks found by clients are propagated through the network (though clients which have full block templates MUST also propagate blocks into the Bitcoin P2P network).

3. **Mining Proxy (optional)**  
   Sits in between Mining Device(s) and Pool Service, aggregating connections for efficiency.
   May optionally provide additional monitoring, receive work from a Job Declarator and use custom work with a pool, or provide other services for a farm.

4. **Job Declarator (optional)**  
   Receives custom block templates from a Template Provider and declares use of the template with the pool using the Job Declaration Protocol.
   Further distributes the jobs to Mining Proxy (or Proxies) using the Job Distribution Protocol. This role will often be a built-in part of a Mining Proxy.

5. **Template Provider**  
   Generates custom block templates to be passed to the Job Declarator for eventual mining.
   This is usually just a Bitcoin Core full node (or possibly some other node implementation).

The Mining Protocol is used for communication between a Mining Device and Pool Service, Mining Device and Mining Proxy, Mining Proxy and Mining Proxy, or Mining Proxy and Pool Service.

The Job Declaration Protocol is used for communication between a Job Declarator and Pool Service.

The Template Distribution Protocol is used for communication either between a Job Declarator and a Template Provider or between a Pool Service and Template Provider.

The Job Distribution Protocol is used for communication between a Job Declarator and a Mining Proxy.

One type of software/hardware can fulfill more than one role (e.g. a Mining Proxy is often both a Mining Proxy and a Job Declarator and may occasionally further contain a Template Provider in the form of a full node on the same device).

Each sub-protocol is based on the same technical principles and requires a connection oriented transport layer, such as TCP.
In specific use cases, it may make sense to operate the protocol over a connectionless transport with FEC or local broadcast with retransmission.
However, that is outside of the scope of this document.
The minimum requirement of the transport layer is to guarantee ordered delivery of the protocol messages.

## 3.1 Data Types Mapping

Message definitions use common data types described here for convenience.
Multibyte data types are always serialized as little-endian.


| Data Type | Byte Length                                                                                  | Description                                                                                                                                                                                                                                                                                                                                                      |
| ------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BOOL          | 1                                                                                            | Boolean value. Encoded as an unsigned 1-bit integer, True = 1, False = 0 with 7 additional padding bits in the high positions. Recipients MUST NOT interpret bits outside of the least significant bit. Senders MAY set bits outside of the least significant bit to any value without any impact on meaning. This allows future use of other bits as flag bits. |
| U8            | 1                                                                                            | Unsigned integer, 8-bit                                                                                                                                                                                                                                                                                                                                          |
| U16           | 2                                                                                            | Unsigned integer, 16-bit, little-endian                                                                                                                                                                                                                                                                                                                          |
| U24           | 3                                                                                            | Unsigned integer, 24-bit, little-endian (commonly deserialized as a 32-bit little-endian integer with a trailing implicit most-significant 0-byte)                                                                                                                                                                                                               |
| U32           | 4                                                                                            | Unsigned integer, 32-bit, little-endian                                                                                                                                                                                                                                                                                                                          |
| U64           | 8                                                                                            | Unsigned integer, 64-bit, little-endian                                                                                                                                                                                                                                                                                                                          |
| U256          | 32                                                                                           | Unsigned integer, 256-bit, little-endian. Often the raw byte output of SHA-256 interpreted as an unsigned integer.                                                                                                                                                                                                                                               |
| STR0_255      | 1 + LENGTH                                                                                   | String with 8-bit length prefix L. Unsigned integer, followed by L bytes. Allowed range of length is 0 to 255. The string is not null-terminated.                                                                                                                                                                                                                |
| B0_32         | 1 + LENGTH                                                                                   | Byte array with 8-bit length prefix L. Unsigned integer, followed by a sequence of L bytes. Allowed range of length is 0 to 32.                                                                                                                                                                                                                                  |
| B0_255        | 1 + LENGTH                                                                                   | Byte array with 8-bit length prefix L. Unsigned integer, followed by a sequence of L bytes. Allowed range of length is 0 to 255.                                                                                                                                                                                                                                 |
| B0_64K        | 2 + LENGTH                                                                                   | Byte array with 16-bit length prefix L. Unsigned little-endian integer followed by a sequence of L bytes. Allowed range of length is 0 to 65535.                                                                                                                                                                                                                 |
| B0_16M        | 3 + LENGTH                                                                                   | Byte array with 24-bit length prefix L. Unsigned integer encoded as U24 above, followed by a sequence of L bytes. Allowed range of length is 0 to 2^24-1.                                                                                                                                                                                                        |
| BYTES         | LENGTH                                                                                       | Arbitrary sequence of LENGTH bytes. See description for how to calculate LENGTH.                                                                                                                                                                                                                                                                                 |
| MAC           | 16                                                                                           | Message Authentication Code produced with AE algorithm                                                                                                                                                                                                                                                                                                           |
| PUBKEY        | 32                                                                                           | X coordinate of Secp256k1 public key (see BIP 340)                                                                                                                                                                                                                                                                                                               |
| SIGNATURE     | 64                                                                                           | Schnorr signature on Secp256k1 (see BIP 340)                                                                                                                                                                                                                                                                                                                     |
| SHORT_TX_ID   | 6                                                                                            | SipHash-2-4(TX_ID, k0, k1) where two most significant bytes are dropped from the SipHash output to make it 6 bytes. TX_ID is 32 byte transaction id and k0 and k1 are U64 siphash keys.                                                                                                                                                                          |
| OPTION[T]     | 1 + (occupied ? size(T) : 0)                                                                 | Alias for SEQ0_1[T]. Identical representation to SEQ0_255 but enforces the maximum size of 1                                                                                                                                                                                                                                                                     |
| SEQ0_32[T]    | Fixed size T: `1 + LENGTH * size(T)  Variable length T:   1 + seq.map(\|x\| x.length).sum()` | 1-byte length L, unsigned integer 8-bits, followed by a sequence of L elements of type T. Allowed range of length is 0 to 32.                                                                                                                                                                                                                                    |
| SEQ0_255[T]   | Fixed size T: `1 + LENGTH * size(T) Variable length T: 1 + seq.map(\|x\| x.length).sum()`    | 1-byte length L, unsigned integer 8-bits, followed by a sequence of L elements of type T. Allowed range of length is 0 to 255.                                                                                                                                                                                                                                   |
| SEQ0_64K[T]   | Fixed size T: `2 + LENGTH * size(T)Variable length T: 2 + seq.map(\|x\| x.length).sum()`     | 2-byte length L, unsigned little-endian integer 16-bits, followed by a sequence of L elements of type T. Allowed range of length is 0 to 65535.                                                                                                                                                                                                                  |
 

## 3.2 Framing

The protocol is binary, with fixed message framing.
Each message begins with the extension type, message type, and message length (six bytes in total), followed by a variable length message.
The message framing is outlined below:

| Protocol Type  | Byte Length | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| extension_type | U16         | Unique identifier of the extension describing this protocol message. <br>Most significant bit (i.e.bit 15, 0-indexed, aka channel_msg) indicates a message which is specific to a channel, whereas if the most significant bit is unset, the message is to be interpreted by the immediate receiving device. <br>Note that the channel_msg bit is ignored in the extension lookup, i.e.an extension_type of 0x8ABC is for the same "extension" as 0x0ABC. <br>If the channel_msg bit is set, the first four bytes of the payload field is a U32 representing the channel_id this message is destined for (these bytes are repeated in the message framing descriptions below). <br>Note that for the Job Declaration and Template Distribution Protocols the channel_msg bit is always unset. |
| msg_type       | U8          | Unique identifier of the extension describing this protocol message                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| msg_length     | U24         | Length of the protocol message, not including this header                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| payload        | BYTES       | Message-specific payload of length msg_length. If the MSB in extension_type (the channel_msg bit) is set the first four bytes are defined as a U32 "channel_id", though this definition is repeated in the message definitions below and these 4 bytes are included in msg_length.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |


## 3.3 Reconnecting Downstream Nodes

An upstream stratum node may occasionally request reconnection of its downstream peers to a different host (e.g. due to maintenance reasons, etc.).
This request is per upstream connection and affects all open channels towards the upstream stratum node.

After receiving a request to reconnect, the downstream node MUST run the handshake protocol with the new node as long as its previous connection was also running through a secure cryptographic session state.

## 3.4 Protocol Extensions

Protocol extensions may be defined by using a non-0 `extension_type` field in the message header (not including the `channel_msg` bit).
The value used MUST either be in the range `0x4000` - `0x7fff` (inclusive, i.e. have the second-to-most-significant-bit set) denoting an "experimental" extension and not be present in production equipment, or have been allocated for the purpose at [http://stratumprotocol.org](http://stratumprotocol.org).
While extensions SHOULD have BIPs written describing their full functionality, `extension_type` allocations MAY also be requested for vendor-specific proprietary extensions to be used in production hardware.
This is done by sending an email with a brief description of the intended use case to the Bitcoin Protocol Development List and extensions@stratumprotocol.org.
(Note that these contacts may change in the future, please check the latest version of this BIP prior to sending such a request.)

Extensions are left largely undefined in this BIP, however, there are some basic requirements that all extensions must comply with/be aware of.
For unknown `extension_type`'s, the `channel_msg` bit in the `extension_type` field determines which device the message is intended to be processed on: if set, the channel endpoint (i.e. either an end mining device, or a pool server) is the final recipient of the message, whereas if unset, the final recipient is the endpoint of the connection on which the message is sent.
Note that in cases where channels are aggregated across multiple devices, the proxy which is aggregating multiple devices into one channel forms the channel’s "endpoint" and processes channel messages.
Thus, any proxy devices which receive a message with the `channel_msg` bit set and an unknown `extension_type` value MUST forward that message to the downstream/upstream device which corresponds with the `channel_id` specified in the first four bytes of the message payload.
Any `channel_id` mapping/conversion required for other channel messages MUST be done on the `channel_id` in the first four bytes of the message payload, but the message MUST NOT be otherwise modified.
If a device is aware of the semantics of a given extension type, it MUST process messages for that extension in accordance with the specification for that extension.

Messages with an unknown `extension_type` which are to be processed locally (as defined above) MUST be discarded and ignored.

Extensions MUST require version negotiation with the recipient of the message to check that the extension is supported before sending non-version-negotiation messages for it.
This prevents the needlessly wasted bandwidth and potentially serious performance degradation of extension messages when the recipient does not support them.

See `ChannelEndpointChanged` message in Common Protocol Messages for details about how extensions interact with dynamic channel reconfiguration in proxies.

## 3.5 Error Codes

The protocol uses string error codes.
The list of error codes can differ between implementations, and thus implementations MUST NOT take any automated action(s) on the basis of an error code.
Implementations/pools SHOULD provide documentation on the meaning of error codes and error codes SHOULD use printable ASCII where possible.
Furthermore, error codes MUST NOT include control characters.

To make interoperability simpler, the following error codes are provided which implementations SHOULD consider using for the given scenarios.
Individual error codes are also specified along with their respective error messages.

- `unknown-user`
- `too-low-difficulty`
- `stale-share`
- `unsupported-feature-flags`
- `unsupported-protocol`
- `protocol-version-mismatch`

## 3.6 Common Protocol Messages

The following protocol messages are common across all of the protocols described in this BIP.

### 3.6.1 `SetupConnection` (Client -> Server)

Initiates the connection.
This MUST be the first message sent by the client on the newly opened connection.
Server MUST respond with either a `SetupConnection.Success` or `SetupConnection.Error` message.
Clients that are not configured to provide telemetry data to the upstream node SHOULD set `device_id` to 0-length strings.
However, they MUST always set vendor to a string describing the manufacturer/developer and firmware version and SHOULD always set `hardware_version` to a string describing, at least, the particular hardware/software package in use.

| Field Name         | Data Type | Description                                                                                                                 |
|--------------------|-----------|-----------------------------------------------------------------------------------------------------------------------------|
| protocol           | U8        | 0 = Mining Protocol <br>1 = Job Declaration <br>2 = Template Distribution Protocol <br> 3 = Job Distribution Protocol        |
| min_version        | U16       | The minimum protocol version the client supports (currently must be 3)                                                      |
| max_version        | U16       | The maximum protocol version the client supports (currently must be 3)                                                      |
| flags              | U32       | Flags indicating optional protocol features the client supports. Each protocol from protocol field as its own values/flags. |
| endpoint_host      | STRO_255  | ASCII text indicating the hostname or IP address                                                                            |
| endpoint_port      | U16       | Connecting port value                                                                                                       |
| Device Information |
| vendor             | STR0_255  | E.g. "Bitmain"                                                                                                              |
| hardware_version   | STR0_255  | E.g. "S9i 13.5"                                                                                                             |
| firmware           | STR0_255  | E.g. "braiins-os-2018-09-22-1-hash"                                                                                         |
| device_id          | STR0_255  | Unique identifier of the device as defined by the vendor                                                                    |


### 3.6.2 `SetupConnection.Success` (Server -> Client)

Response to `SetupConnection` message if the server accepts the connection.
The client is required to verify the set of feature flags that the server supports and act accordingly.

| Field Name   | Data Type | Description                                                                                                                                             |
|--------------|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| used_version | U16       | Selected version proposed by the connecting node that the upstream node supports. This version will be used on the connection for the rest of its life. |
| flags        | U32       | Flags indicating optional protocol features the server supports. Each protocol from protocol field has its own values/flags.                            |

### 3.6.3 `SetupConnection.Error` (Server -> Client)

When protocol version negotiation fails (or there is another reason why the upstream node cannot setup the connection) the server sends this message with a particular error code prior to closing the connection.

In order to allow a client to determine the set of available features for a given server (e.g. for proxies which dynamically switch between different pools and need to be aware of supported options), clients SHOULD send a SetupConnection message with all flags set and examine the (potentially) resulting `SetupConnection.Error` message’s flags field.
The Server MUST provide the full set of flags which it does not support in each `SetupConnection.Error` message and MUST consistently support the same set of flags across all servers on the same hostname and port number.
If flags is 0, the error is a result of some condition aside from unsupported flags.

| Field Name | Data Type | Description                                                 |
| ---------- | --------- | ----------------------------------------------------------- |
| flags      | U32       | Flags indicating features causing an error                  |
| error_code | STR0_255  | Human-readable error code(s), see Error Codes section below |

Possible error codes:

- `unsupported-feature-flags`
- `unsupported-protocol`
- `protocol-version-mismatch`

### 3.6.4 `ChannelEndpointChanged` (Server -> Client)

When a channel’s upstream or downstream endpoint changes and that channel had previously sent messages with **`channel_msg`** bitset of unknown `extension_type`, the intermediate proxy MUST send a **`ChannelEndpointChanged`** message.
Upon receipt thereof, any extension state (including version negotiation and the presence of support for a given extension) MUST be reset and version/presence negotiation must begin again.

| Field Name | Data Type | Description                           |
| ---------- | --------- | ------------------------------------- |
| channel_id | U32       | The channel which has changed enpoint |
