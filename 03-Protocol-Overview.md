# 3. Protocol Overview

There are technically four distinct (sub)protocols needed in order to fully use all of the features proposed in this document:

1. **Mining Protocol**  
   Direct successor to Stratum v1. A mining device uses this main protocol to communicate with its upstream node, pool, or proxy. A proxy uses it to communicate with a pool (or another proxy). Must be implemented in all scenarios. Only protocol used if a miner/pool does not support transaction selection.

2. **Job Negotiation Protocol**  
   Miners (or mining farms) negotiate block templates with pool. Pool can reuse negotiation outcomes across all end-miner connections to reduce computational intensity. A single negotiation can multicast to multiple farms with hundreds of thousands of devices.
   Separating job negotiation as a sub-protocol lets pools terminate negotiation connections independently of mining protocol connections (i.e. share submissions).
   Work negotiation likely requires, at minimum, validity spot-checks and (potentially) rate-limiting.

3. **Template Distribution Protocol**  
   Fetch next block from Bitcoin Core.
   Replaces `getblocktemplate` with more efficient protocol (and is easier to implement in conjunction with other Stratum v2 modules).

4. **Job Distribution Protocol**  
   Pass newly-negotiated work to interested nodes - via proxy or directly to miners.
   Specifications for this sub-protocol fall outside the scope of this document.

Five roles (types of software/hardware) for communicating between & among these protocols:

1. **Mining Device**  
   Produces hashes. Further subdivided into 'header-only' mining devices & 'standard' mining devices. (Most devices will likely support both modes.)

2. **Pool Service**  
   Produces jobs (or relays Job Negotiation Protocol outcomes), validates shares, & propagates clients' found blocks through the network (though clients which have full block templates MUST also propagate blocks into the Bitcoin P2P network).

3. **Mining Proxy (optional)**  
   Sits between Mining Device(s) and Pool Service, aggregating connections for efficiency.
   Optionally provides additional monitoring, receives work from a Job Negotiator, uses custom work with a pool, or provides other services for a farm.

4. **Job Negotiator (optional)**  
   Receives custom block templates from Template Provider and negotiates template use with the pool per Job Negotiation Protocol.
   Further distributes jobs to Mining Proxy (or Proxies) via the Job Distribution Protocol. Role optionally built into the Mining Proxy.

5. **Template Provider**  
   Generates custom block templates,, passed to Job Negotiator for eventual mining.
   (Usually a Bitcoin Core full node, or some other node implementation.)

The Mining Protocol communicates between Mining Device and Pool Service, Mining Device and Mining Proxy, Mining Proxy and Mining Proxy, or Mining Proxy and Pool Service.

The Job Negotiation Protocol communicates between Job Negotiator and Pool Service.

The Template Distribution Protocol communicates between Job Negotiator and Template Provider.

The Job Distribution Protocol communicates between Job Negotiator and a Mining Proxy.

Software/hardware can fill multiple roles (e.g. Mining Proxy is often both a Mining Proxy and a Job Negotiator, and may occasionally further contain a Template Provider as a full node process on the same device).

Each sub-protocol employs the same technical principles and requires a connection oriented transport layer like TCP.
Can, depending on circumstance and requirements, operate the protocol over a connectionless transport with FEC or local broadcast with retransmission. Such a configuration is outside of the scope of this document.
The minimum requirement of the transport layer is to guarantee ordered delivery of the protocol messages.

## 3.1 Data Types Mapping

Message definitions use common data types described below.
Multibyte data types are always serialized as little-endian.

```
+---------------+---------------------------------+--------------------------------------------------------------------+
| Protocol Type | Byte Length                     | Description                                                        |
+---------------+---------------------------------+--------------------------------------------------------------------+
| BOOL          | 1                               | Boolean value. Encoded as an unsigned 1-bit integer, True = 1,     |
|               |                                 | False = 0 with 7 additional padding bits in the high positions.    |
|               |                                 |                                                                    |
|               |                                 | Recipients MUST NOT interpret bits outside of the least            |
|               |                                 | significant bit. Senders MAY set bits outside of the least         |
|               |                                 | significant bit to any value without any impact on meaning. This   |
|               |                                 | allows future use of other bits as flag bits.                      |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U8            | 1                               | Unsigned integer, 8-bit                                            |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U16           | 2                               | Unsigned integer, 16-bit, little-endian                            |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U24           | 3                               | Unsigned integer, 24-bit, little-endian (commonly deserialized as  |
|               |                                 | a 32-bit little-endian integer with a trailing implicit            |
|               |                                 | most-significant 0-byte)                                           |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U32           | 4                               | Unsigned integer, 32-bit, little-endian                            |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U256          | 32                              | Unsigned integer, 256-bit, little-endian. Often the raw byte       |
|               |                                 | output of SHA-256 interpreted as an unsigned integer.              |
+---------------+---------------------------------+--------------------------------------------------------------------+
| STR0_255      | 1 + LENGTH                      | 1-byte length L, unsigned integer 8-bits, followed by a series of  |
|               |                                 | L bytes. Allowed range of length is 0 to 255. The string is not    |
|               |                                 | null-terminated.                                                   |
+---------------+---------------------------------+--------------------------------------------------------------------+
| B0_255        | 1 + LENGTH                      | 1-byte length L, unsigned integer 8-bits, followed by a sequence   |
|               |                                 | of L bytes. Allowed range of length is 0 to 255.                   |
+---------------+---------------------------------+--------------------------------------------------------------------+
| B0_64K        | 2 + LENGTH                      | 2-byte length L, unsigned little-endian integer 16-bits followed   |
|               |                                 | by a sequence of L bytes. Allowed range of length is 0 to 65535.   |
+---------------+---------------------------------+--------------------------------------------------------------------+
| B0_16M        | 3 + LENGTH                      | 3-byte length L, encoded as U24 above, followed by a sequence of L |
|               |                                 | bytes. Allowed range of length is 0 to 2^24-1.                     |
+---------------+---------------------------------+--------------------------------------------------------------------+
| BYTES         | LENGTH                          | Arbitrary sequence of LENGTH bytes. See description for how to     |
|               |                                 | calculate LENGTH.                                                  |
+---------------+---------------------------------+--------------------------------------------------------------------+
| PUBKEY        | 32                              | ED25519 public key                                                 |
+---------------+---------------------------------+--------------------------------------------------------------------+
| SIGNATURE     | 2 + LENGTH                      | ED25519 signature                                                  |
| (alias for    |                                 |                                                                    |
|  BO_64K)      |                                 |                                                                    |
+---------------+---------------------------------+--------------------------------------------------------------------+
| SEQ0_255[T]   | Fixed size T:                   | 1-byte length L, unsigned integer 8-bits, followed by a sequence   |
|               | 1 + LENGTH * size(T)            | of L elements of type T. Allowed range of length is 0 to 255.      |
|               | Variable length T:              |                                                                    |
|               | 1 + seq.map(|x| x.length).sum() |                                                                    |
+---------------+---------------------------------+--------------------------------------------------------------------+
| SEQ0_64K[T]   | Fixed size T:                   | 2-byte length L, unsigned little-endian integer 16-bits, followed  |
|               | 2 + LENGTH * size(T)            | by a sequence of L elements of type T. Allowed range of length is  |
|               | Variable length T:              | 0 to 65535.                                                        |
|               | 2 + seq.map(|x| x.length).sum() |                                                                    |
+---------------+---------------------------------+--------------------------------------------------------------------+
```

## 3.2 Framing

The protocol is binary, with fixed message framing.
Each message begins with 6 bytes:

- extension type (2-bytes)
- message type (1-byte)
- message length (3-bytes)

Followed by a variable length message.

**Message Framing Outline**

```
+----------------+-------------+---------------------------------------------------------------------------------------+
| Protocol Type  | Byte Length | Description                                                                           |
+----------------+-------------+---------------------------------------------------------------------------------------+
| extension_type | U16         | Unique extension identifier describing this protocol message.                         |
|                |             |                                                                                       |
|                |             | Most significant bit (MSB) (i.e.bit 15, 0-indexed, aka channel_msg) indicates         |
|                |             | a channel specific message. If unset, the message is interpreted by the immediate     |
                 |             | receiving device.                                                                     |
|                |             |                                                                                       |
|                |             | Note: the channel_msg bit is ignored in the extension lookup,                         |
|                |             |       i.e. an extension_type of 0x8ABC is for the same "extension" as 0x0ABC.         |
|                |             |                                                                                       |
|                |             | If channel_msg bit set, first four bytes of payload is a U32 representing the         |
|                |             | message's destination channel-id.                                                     |
|                |             | (These bytes are repeated in the message framing descriptions below.)                 |
|                |             |                                                                                       |
|                |             | Note: channel_msg bit always unset for the Job Negotiation and Template               |
|                |             |       Distribution Protocols.                                                         |
+----------------+-------------+---------------------------------------------------------------------------------------+
| msg_type       | U8          | Unique extension identifier describing this protocol message.                         |
+----------------+-------------+---------------------------------------------------------------------------------------+
| msg_length     | U24         | Length of the protocol message (excluding this header)                                |
+----------------+-------------+---------------------------------------------------------------------------------------+
| payload        | BYTES       | Message-specific payload of length msg_length. If MSB in extension_type               |
|                |             | (the channel_msg bit) is set, first 4 bytes defined as a U32 "channel_id",            |
|                |             | definition is repeated in the message definitions below.                              |
|                |             | These 4 bytes are included in msg_length.                                             |
+----------------+-------------+---------------------------------------------------------------------------------------+

```

## 3.3 Protocol Security

Stratum V2 uses the AEAD encryption scheme (authenticated encryption with associated data) to secure client<->server communication. AEAD provides confidentiality & integrity guarantees for both encrypted ciphertexts and unencrypted associated data.
Prior to opening Stratum V2 mining channels, clients MUST initiate the cryptographic session state used to encrypt client<->server messages. The cryptographic session state is independent of V2 messaging conventions.

This specification simultaneously proposes optional use of of the **[Noise Protocol framework](https://noiseprotocol.org/noise.html)** handshake.
Client and server establish secure communication using Diffie-Hellman (DH) key exchange, as described in the **Authenticated Key Agreement Handshake** section below.

The handshake protocol for secured communication is **optional** on the local network (i.e. local mining devices talking to a local mining proxy).
The handshake is **mandatory** for remote access to upstream nodes (pool mining services, job negotiating services or template distributors).

### 3.3.1 Motivation for Authenticated Encryption with Associated Data

Data transferred by the mining protocol MUST NOT provide an adversary information to estimate any particular miner's performance.
Any submitted shares information allows miner’s earnings estimations, and can be mapped to a particular username.
This is an unacceptable privacy leak.

### 3.3.2 Motivation for Using the Noise Protocol Framework

- The Noise Framework pushes to use modern cryptography.
- The Noise Framework provides formal, verifiable handshake protocol description.
- No legacy overhead.
- Difficult to get wrong.
- Noise Explorer provides code generators for popular programming languages.
- Can specify no flexibility (i.e. fewer degrees of freedom), ensuring standardized ciphersuite(s) support.
- Custom certificate scheme possible (no need to use x509 certificates).

### 3.3.3 Authenticated Key Agreement Handshake

The **`Noise_NX_25519_<encryption-algorithm>_BLAKE2s`** handshake provides server-side authentication & does not require initiator (client) authentication.
We achieve server authentication via a series of Elliptic-Curve Diffie-Hellman (ECDH) operations, followed by a MAC check.

The authenticated key agreement (`Noise NX`) is performed in three distinct steps (acts).

1. Encryption Algorithm Negotiation: Initiator provides a list of supported encryption algorithms to Responder; list
   is mixed into the hash digest on noise Symmetric State initialization as a noise Prologue. Responder mixes received list to thier hash digest and sends chosen algorithm to the initiator.
   (Note: if Responder uses different prologue than Initiator, noise handshake fails.)
2. Ephemeral & Static Key Exchange, followed by ECDH: keying material sent to other party; pertform ECDH,
   result mixed into current set of encryption keys.
   `ck == chaining key`
   `k == encryption key`
3. Server Authentication with Signature Noise Message: Initiator verifies received SIGNATURE_NOISE_MESSAGE in previous step as a handshake payload.

ECDH outputs mix into a hash digest forms an 'incremental DoubleDH handshake'.

Per Noise Protocol language, **`e`** and **`s`** (both public keys where **`e == ephemeral key`** and `**s == static key**`) indicate possibly encrypted keying material, and **`es`**, **`ee`**, and **`se`** each indicate an ECDH operation between two keys.

**Handshake Protocol**

```
   Noise_NX:
       -> [LIST_OF_SUPPORTED_ENCRYPTION_ALGORITHM]
       <- [CHOSEN_ENCRYPTION_ALGORITHM]
       -> e
       <- e, ee, s, es, SIGNATURE_NOISE_MESSAGE
```

Last handshake message followed by a `SIGNATURE_NOISE_MESSAGE`.
This additional message authenticates the stratum server to the downstream node.
The certificate implements a simple 2-level public key infrastructure.

Each server operator has a long-term authority keypair, and each stratum-server has a certificate, signed by the authority private key, authenticating itself to clients.
The certificate has time-limited validity, and is signed by the central pool authority.

### 3.3.4 Noise message framing

Every message sent over the wire for a handshake or established session is prefixed with payload
length (two-bytes, little-endian)

```
+----------------------------+-------------------------------------------------------------------+
| length prefix [2 Bytes]    |  Handshake message or encrypted message                           |
+----------------------------+-------------------------------------------------------------------+
```

### 3.3.5 Signature Noise Message

Message serialized similarly to other stratum messages:

- Server Certificate header (`version`, `valid_from` and `not_not_valid_after` fields)
- ED25519 signature verifiable by the Pool Authority Public key. Client can reconstruct the full Certificate from its "`s`" and this header to authenticate the server.

```
+-----------------+-----------+----------------------------------------------------------------------------------------+
| Field Name      | Data Type | Description                                                                            |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| version         | U16       | Version of the certificate format                                                      |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| valid_from      | U32       | Validity start time (UNIX timestamp)                                                   |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| not_valid_after | U32       | Signature invalid after this time (UNIX timestamp)                                     |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| signature       | SIGNATURE | ED25519 signature                                                                      |
+-----------------+-----------+----------------------------------------------------------------------------------------+
```

### 3.3.6 Certificate Format

Signature constructed over fields marked for signing after serialization using Stratum protocol binary serialization format.

```
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| Field Name           | Data Type | Description                                                        | Signed Feild |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| version              | U16       | Version of the certificate format                                  | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| valid_from           | U32       | Validity start time (UNIX timestamp)                               | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| not_valid_after      | U32       | Signature invalid after this time (UNIX timestamp)                 | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| authority_public_key | PUBKEY    | Public key for signature verification                              | NO           |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| signature            | SIGNATURE | ED25519                                                            | NO           |
+----------------------+-----------+-----------------------------------------------------------------------------------+
```

### 3.3.6 URL Scheme and Pool Authority Key

To use the security scheme outlined above, downstream nodes must configure the **Pool Authority Key** for intended pool connection.
Embed key into the mining URL as part of the path.
E.g.:

```
stratum2+tcp://thepool.com/u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt
```

"**`u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt`**" is the public key in [base58-check](https://en.bitcoin.it/wiki/Base58Check_encoding) encoding.
Provided by target pool, communicated to its users via a trusted channel.
(Can be published on the pool's public website.)

## 3.4 Reconnecting Downstream Nodes

An upstream stratum node may occasionally request reconnection of downstream peers to a different host (e.g. maintenance reasons, etc.).
This request is per upstream connection and affects all open channels towards the upstream stratum node.

After receiving a reconnect request, downstream node MUST run the handshake protocol with the new node. (As long as its previous connection was also running through a secure cryptographic session state.)

## 3.5 Protocol Extensions

Defined with a non-0 `extension_type` field in the message header (not including the `channel_msg` bit).
Value MUST **either**:

- be in the range `0x4000` - `0x7fff` (inclusive, i.e. have the second-to-most-significant-bit set) denoting an "experimental" extension & not be present in production equipment
- or have been allocated for the purpose at [http://stratumprotocol.org](http://stratumprotocol.org).
  While extensions SHOULD have BIPs written describing their full functionality, `extension_type` allocations MAY also be requested for vendor-specific proprietary extensions for production hardware.
  Send an email with a brief description of the intended use case to the Bitcoin Protocol Development List and extensions@stratumprotocol.org.
  (Note: these contacts may change in the future, please check the latest version of this BIP prior to sending such a request.)

We leave extensions largely undefined in this BIP. Some basic requirements that all extensions must comply with/be aware of:

- For unknown `extension_type`'s, the `channel_msg` bit in the `extension_type` field determines which device the message is intended to be processed on:
  - If set: the channel endpoint (i.e. either an end mining device, or a pool server) is the final recipient of the message.
  - If unset, the final recipient is the endpoint of the connection on which the message is sent.
    (Note: if channels aggregated across multiple devices, the aggregating proxy forms the channel’s "endpoint" and processes channel messages.)
    Proxy devices receiving a message with `channel_msg` bit set and an unknown `extension_type` MUST forward that message to the downstream/upstream device mapping to the `channel_id` (specified in the first four bytes of the message payload).
    Any `channel_id` mapping/conversion required for other channel messages MUST be done on the `channel_id` in the first four bytes of the message payload. The message MUST NOT be otherwise modified.
    If a device is aware of the semantics of a given extension type, it MUST process messages for that extension according to the specification for that extension.

Locally processed messages with unknown `extension_type` (as defined above) MUST be discarded and ignored.

Extensions MUST require version negotiation with the message recipient to check extension support before sending non-version-negotiation messages for it.
This prevents wasted bandwidth and potentially serious performance degradation of extension messages if unsupported.

See `ChannelEndpointChanged` message in Common Protocol Messages for how extensions interact with dynamic channel reconfiguration in proxies.

## 3.6 Error Codes

The protocol uses string error codes. The list of error codes can differ between implementations.
Implementations MUST NOT take any automated action(s) on the basis of an error code.
Implementations/pools SHOULD provide documentation on the meaning of error codes and error codes SHOULD use printable ASCII where possible.
Error codes MUST NOT include control characters.

We provide the following error codes which implementations SHOULD use for simplicity.
We specify individual error codes with their respective error messages.

- `unknown-user`
- `too-low-difficulty`
- `stale-share`
- `unsupported-feature-flags`
- `unsupported-protocol`
- `protocol-version-mismatch`

## 3.7 Common Protocol Messages

Protocol messages common across all protocols described in this BIP.

### 3.7.1 `SetupConnection` (Client -> Server)

Initiates the connection.
MUST be the first message sent by the client on the newly opened connection.
Server MUST respond with either:

- `SetupConnection.Success`
- or `SetupConnection.Error` message
  Clients SHOULD set `device_id` to 0-length strings if not configured to provide upstream node with telemetry data .
  Clients MUST always set vendor to a string describing the manufacturer/developer and firmware version.
  Clients SHOULD always set `hardware_version` to a string describing, at least, the particular hardware/software package in use.

```
+------------------+-----------+----------------------------------------------------------------------------------------+
| Field Name       | Data Type | Description                                                                            |
+------------------+-----------+----------------------------------------------------------------------------------------+
| protocol         | U8        | 0 = Mining Protocol                                                                    |
|                  |           | 1 = Job Negotiaion Protocol                                                            |
|                  |           | 2 = Template Distribution Protocol                                                     |
|                  |           | 3 = Job Distribution Protocol                                                          |
+------------------+-----------+----------------------------------------------------------------------------------------+
| min_version      | U16       | The minimum protocol version the client supports (currently must be 2)                 |
+------------------+-----------+----------------------------------------------------------------------------------------+
| max_version      | U16       | The maximum protocol version the client supports (currently must be 2)                 |
+------------------+-----------+----------------------------------------------------------------------------------------+
| flags            | U32       | Flags indicating optional protocol features the client supports. Each protocol from    |
|                  |           | protocol field as its own values/flags.                                                |
+------------------+-----------+----------------------------------------------------------------------------------------+
| endpoint_host    | U32       | ASCII text indicating the hostname or IP address                                       |
+------------------+-----------+----------------------------------------------------------------------------------------+
| endpoint_port    | U16       | Connecting port value                                                                  |
+------------------+-----------+----------------------------------------------------------------------------------------+
|                                                   Device Information                                                  |
+------------------+-----------+----------------------------------------------------------------------------------------+
| vendor           | STR0_255  | E.g. "Bitmain"                                                                         |
+------------------+-----------+----------------------------------------------------------------------------------------+
| hardware_version | STR0_255  | E.g. "S9i 13.5"                                                                        |
+------------------+-----------+----------------------------------------------------------------------------------------+
| firmware         | STR0_255  | E.g. "braiins-os-2018-09-22-1-hash"                                                    |
+------------------+-----------+----------------------------------------------------------------------------------------+
| device_id        | STR0_255  | Unique identifier of the device as defined by the vendor                               |
+------------------+-----------+----------------------------------------------------------------------------------------+
```

### 3.7.2 `SetupConnection.Success` (Server -> Client)

Response to `SetupConnection` message if server accepts connection.
Client MUST verify server's supported feature flags and act accordingly.

```
+--------------+-----------+-------------------------------------------------------------------------------------------+
| Field Name   | Data Type | Description                                                                               |
+--------------+-----------+-------------------------------------------------------------------------------------------+
| used_version | U16       | Selected version proposed by the connecting node that the upstream node supports. This    |
|              |           | version will be used on the connection for the rest of its life.                          |
+--------------+-----------+-------------------------------------------------------------------------------------------+
| flags        | U32       | Flags indicating optional protocol features the server supports. Each protocol from       |
|              |           | protocol field has its own values/flags.                                                  |
+--------------+-----------+-------------------------------------------------------------------------------------------+
```

### 3.7.3 `SetupConnection.Error` (Server -> Client)

When protocol version negotiation fails (or upstream node cannot setup connection) server sends this message with a specific error code prior to closing connection.

Clients SHOULD send a SetupConnection message with all flags set and examine the (potentially) resulting `SetupConnection.Error` message’s flags field. This allows client to determine server's supported feature set (e.g. for proxies which dynamically switch between different pools),
Server MUST provide the full set of unsupported flags in each `SetupConnection.Error` message and MUST consistently support the same set of flags across all servers on the same hostname and port number.
If flags == 0, error is some condition aside from unsupported flags.

```
+------------+-----------+---------------------------------------------------------------------------------------------+
| Field Name | Data Type | Description                                                                                 |
+------------+-----------+---------------------------------------------------------------------------------------------+
| flags      | U32       | Flags indicating features causing an error                                                  |
+------------+-----------+---------------------------------------------------------------------------------------------+
| error_code | STR0_255  | Human-readable error code(s) (see Error Codes section below)                                |
+------------+-----------+---------------------------------------------------------------------------------------------+
```

Possible error codes:

- `unsupported-feature-flags`
- `unsupported-protocol`
- `protocol-version-mismatch`

### 3.7.4 `ChannelEndpointChanged` (Server -> Client)

When a channel’s upstream or downstream endpoint changes and channel previously sent messages with **`channel_msg`** bitset of unknown `extension_type`, intermediate proxy MUST send a **`ChannelEndpointChanged`** message.
On receipt, any extension state (including version negotiation and any given extension support) MUST reset version/presence negotiation.

```
+------------+-----------+----------------------------------------------------------------------------------------+
| Field Name | Data Type | Description                                                                            |
+------------+-----------+----------------------------------------------------------------------------------------+
| channel_id | U32       | Changed channel endpoint                                                               |
+------------+-----------+----------------------------------------------------------------------------------------+
```
