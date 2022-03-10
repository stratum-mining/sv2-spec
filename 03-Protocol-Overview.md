# 3. Protocol Overview
There are technically four distinct (sub)protocols needed in order to fully use all of the features proposed in this document:

1. **Mining Protocol**  
    The main protocol used for mining and the direct successor of Stratum v1.
    A mining device uses it to communicate with its upstream node, pool, or a proxy.
    A proxy uses it to communicate with a pool (or another proxy).
    This protocol needs to be implemented in all scenarios.
    For cases in which a miner or pool does not support transaction selection, this is the only protocol used.

2. **Job Negotiation Protocol**  
    Used by a miner (a whole mining farm) to negotiate a block template with a pool.
    Results of this negotiation can be re-used for all mining connections to the pool to reduce computational intensity.
    In other words, a single negotiation can be used by an entire mining farm or even multiple farms with hundreds of thousands of devices, making it far more efficient.
    This is separate to allow pools to terminate such connections on separate infrastructure from mining protocol connections (i.e. share submissions).
    Further, such connections have very different concerns from share submissions - work negotiation likely requires, at a minimum, some spot-checking of work validity, as well as potentially substantial rate-limiting (without the inherent rate-limiting of share difficulty).

3. **Template Distribution Protocol**  
   A similarly-framed protocol for getting information about the next block out of Bitcoin Core.
   Designed to replace `getblocktemplate` with something much more efficient and easy to implement for those implementing other parts of Stratum v2.

4. **Job Distribution Protocol**  
   Simple protocol for passing newly-negotiated work to interested nodes - either proxies or miners directly.
   This protocol is left to be specified in a future document, as it is often unnecessary due to the Job Negotiation role being a part of a larger Mining Protocol Proxy.


Meanwhile, there are five possible roles (types of software/hardware) for communicating with these protocols.

1. **Mining Device**  
   The actual device computing the hashes. This can be further divided into header-only mining devices and standard mining devices, though most devices will likely support both modes.

2. **Pool Service**  
   Produces jobs (for those not negotiating jobs via the Job Negotiation Protocol), validates shares, and ensures blocks found by clients are propagated through the network (though clients which have full block templates MUST also propagate blocks into the Bitcoin P2P network).

3. **Mining Proxy (optional)**  
   Sits in between Mining Device(s) and Pool Service, aggregating connections for efficiency.
   May optionally provide additional monitoring, receive work from a Job Negotiator and use custom work with a pool, or provide other services for a farm.

4. **Job Negotiator (optional)**  
   Receives custom block templates from a Template Provider and negotiates use of the template with the pool using the Job Negotiation Protocol.
   Further distributes the jobs to Mining Proxy (or Proxies) using the Job Distribution Protocol. This role will often be a built-in part of a Mining Proxy.

5. **Template Provider**  
   Generates custom block templates to be passed to the Job Negotiator for eventual mining.
   This is usually just a Bitcoin Core full node (or possibly some other node implementation).


The Mining Protocol is used for communication between a Mining Device and Pool Service, Mining Device and Mining Proxy, Mining Proxy and Mining Proxy, or Mining Proxy and Pool Service.

The Job Negotiation Protocol is used for communication between a Job Negotiator and Pool Service.

The Template Distribution Protocol is used for communication between a Job Negotiator and Template Provider.

The Job Distribution Protocol is used for communication between a Job Negotiator and a Mining Proxy.

One type of software/hardware can fulfill more than one role (e.g. a Mining Proxy is often both a Mining Proxy and a Job Negotiator and may occasionally further contain a Template Provider in the form of a full node on the same device).

Each sub-protocol is based on the same technical principles and requires a connection oriented transport layer, such as TCP.
In specific use cases, it may make sense to operate the protocol over a connectionless transport with FEC or local broadcast with retransmission.
However, that is outside of the scope of this document.
The minimum requirement of the transport layer is to guarantee ordered delivery of the protocol messages.


## 3.1 Data Types Mapping
Message definitions use common data types described here for convenience.
Multibyte data types are always serialized as little-endian.


```
+---------------+---------------------------------+--------------------------------------------------------------------+
| Protocol Type | Byte Length                     | Description                                                        |
+---------------+---------------------------------+--------------------------------------------------------------------+
| BOOL          | 1                               | Boolean value. Encoded as an unsigned 1-bit integer, True = 1,     |
|               |                                 | False = 0 with 7 additional padding bits in the high positions.    |
|               |                                 |                                                                    |                                                                                                                                                                                                                                                                                              |
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
|               |                                 | most-significant 0-byte).                                          |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U32           | 4                               | Unsigned integer, 32-bit, little-endian                            |
+---------------+---------------------------------+--------------------------------------------------------------------+
| U256          | 32                              | Unsigned integer, 256-bit, little-endian                           |
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
Each message begins with the extension type, message type, and message length (six bytes in total), followed by a variable length message.
The message framing is outlined below:

```
+----------------+-------------+---------------------------------------------------------------------------------------+
| Protocol Type  | Byte Length | Description                                                                           |
+----------------+-------------+---------------------------------------------------------------------------------------+
| extension_type | U16         | Unique identifier of the extension describing this protocol message.                  |
|                |             |                                                                                       |
|                |             | Most significant bit (i.e.bit 15, 0-indexed, aka channel_msg) indicates a message     |
|                |             | which is specific to a channel, whereas if the most significant bit is unset, the     |
|                |             | message is to be interpreted by the immediate receiving device.                       |
|                |             |                                                                                       |
|                |             | Note that the channel_msg bit is ignored in the extension lookup, i.e.an              |
|                |             | extension_type of 0x8ABC is for the same "extension" as 0x0ABC.                       |
|                |             |                                                                                       |
|                |             | If the channel_msg bit is set, the first four bytes of the payload field is a U32     |
|                |             | representing the channel_id this message is destined for (these bytes are repeated in |
|                |             | the message framing descriptions below).                                              |
|                |             |                                                                                       |
|                |             | Note that for the Job Negotiation and Template Distribution Protocols the channel_msg |
|                |             | bit is always unset.                                                                  |
+----------------+-------------+---------------------------------------------------------------------------------------+
| msg_type       | U8          | Unique identifier of the extension describing this protocol message.                  |
+----------------+-------------+---------------------------------------------------------------------------------------+
| msg_length     | U24         | Length of the protocol message, not including this header.                            |
+----------------+-------------+---------------------------------------------------------------------------------------+
| payload        | BYTES       | Message-specific payload of length msg_length. If the MSB in extension_type           |
|                |             | (the channel_msg bit) is set the first four bytes are defined as a U32 "channel_id",  |
|                |             | though this definition is repeated in the message definitions below and these 4 bytes |
|                |             | are included in msg_length.                                                           |
+----------------+-------------+---------------------------------------------------------------------------------------+

```


## 3.3 Protocol Security
Stratum V2 employs a type of encryption scheme called AEAD (authenticated encryption with associated data) to address the security aspects of all communication that occurs between clients and servers.
This provides both confidentiality and integrity for the ciphertexts (i.e. encrypted data) being transferred, as well as providing integrity for associated data which is not encrypted.
Prior to opening any Stratum V2 channels for mining, clients MUST first initiate the cryptographic session state that is used to encrypt all messages sent between themselves and servers.
Thus, the cryptographic session state is independent of V2 messaging conventions.

At the same time, this specification proposes optional use of a particular handshake protocol based on the **[Noise Protocol framework](https://noiseprotocol.org/noise.html)**.
The client and server establish secure communication using Diffie-Hellman (DH) key agreement, as described in greater detail in the Authenticated Key Agreement Handshake section below.

Using the handshake protocol to establish secured communication is **optional** on the local network (e.g. local mining devices talking to a local mining proxy).
However, it is **mandatory** for remote access to the upstream nodes, whether they be pool mining services, job negotiating services or template distributors.


### 3.3.1 Motivation for Authenticated Encryption with Associated Data
Data transferred by the mining protocol MUST not provide adversary information that they can use to estimate the performance of any particular miner.
Any intelligence about submitted shares can be directly converted to estimations of a miner’s earnings and can be associated with a particular username.
This is unacceptable privacy leakage that needs to be addressed.


### 3.3.2 Motivation for Using the Noise Protocol Framework
The reasons why Noise Protocol Framework has been chosen are listed below:

- The Framework pushes to use new, modern cryptography.
- The Framework provides a formalism to describe the handshake protocol that can be verified.
- There is no legacy overhead.
- It is difficult to get wrong.
- Noise Explorer provides code generators for popular programming languages (e.g. Go, Rust).
- We can specify no flexibility (i.e. fewer degrees of freedom), helping ensure standardization of the supported ciphersuite(s).
- A custom certificate scheme is now possible (no need to use x509 certificates).


### 3.3.3 Authenticated Key Agreement Handshake
The handshake chosen for the authenticated key exchange is **`Noise_NX`** as it provides authentication of the server side and does not require authentication of the initiator (client).
Server authentication is achieved implicitly via a series of Elliptic-Curve Diffie-Hellman (ECDH) operations followed by a MAC check.

The authenticated key agreement (`Noise_NX`) is performed in two distinct steps (acts).
The protocol allows for secure authentication.
During each act of the handshake the following occurs: some (possibly encrypted) keying material is sent to the other party; an ECDH is performed, based on exactly which act is being executed, with the result mixed into the current set of encryption keys (`ck` the chaining key and `k` the encryption key); and an AEAD payload with a zero-length cipher text is sent.
As this payload has no length, only a MAC is sent across.
The mixing of ECDH outputs into a hash digest forms an incremental DoubleDH handshake.

Using the language of the Noise Protocol, **`e`** and **`s`** (both public keys with `**e**` being the **ephemeral key** and `**s**` being the **static key**) indicate possibly encrypted keying material, and **`es`**, **`ee`**, and **`se`** each indicate an ECDH operation between two keys.
The handshake is laid out as follows:

```
   Noise_NX(s, rs):
      
       -> e
       <- e, ee, s, es, SIGNATURE_NOISE_MESSAGE
```

The second handshake message is followed by a `SIGNATURE_NOISE_MESSAGE`.
Using this additional message allows us to authenticate the stratum server to the downstream node.
The certificate implements a simple 2 level public key infrastructure. 
The main idea is that each stratum server is equipped with a certificate (that confirms its identity by providing signature of its "static public key" aka "**`s`**").
The certificate has time limited validity and is signed by the central pool authority.


### 3.3.4 Signature Noise Message
This message uses the same serialization format as other stratum messages.
It contains serialized:

- Server Certificate header (`version`, `valid_from` and `not_not_valid_after` fields)
- ED25519 signature that can be verified by the Pool Authority Public key and the client can reconstruct the full Certificate from its "`s`" and this header and authenticate the server. 

```
+-----------------+-----------+----------------------------------------------------------------------------------------+
| Field Name      | Data Type | Description                                                                            |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| version         | U16       | Version of the certificate format                                                      |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| valid_from      | U32       | Validity start time (unix timestamp)                                                   |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| not_valid_after | U32       | Signature is invalid after this point in time (unix timestamp)                         |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| signature       | SIGNATURE | ED25519 signature                                                                      |
+-----------------+-----------+----------------------------------------------------------------------------------------+
```


### 3.3.5 Certificate Format
Stratum server certificates have the following layout.
The signature is  constructed over the fields marked for signing after serialization using Stratum protocol binary serialization format.

```
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| Field Name           | Data Type | Description                                                        | Signed Feild |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| version              | U16       | Version of the certificate format                                  | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| valid_from           | U32       | Validity start time (unix timestamp)                               | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| not_valid_after      | U32       | Signature is invalid after this pont in time (unix timestamp)      | YES          |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| authority_public_key | PUBKEY    | Public key used for verfication of the signature                   |              |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| signature            | SIGNATURE | ED25519                                                            |              |
+----------------------+-----------+-----------------------------------------------------------------------------------+
```


### 3.3.6 URL Scheme and Pool Authority Key
Downstream nodes that want to use the above outlined security scheme need to have configured the **Pool Authority Key** of the pool that they intend to connect to.
The key can be embedded into the mining URL as part of the path.
E.g.:

```
stratum2+tcp://thepool.com/u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt
```

The "**`u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt`**" is the public key in [base58-check](https://en.bitcoin.it/wiki/Base58Check_encoding) encoding.
It is provided by the target pool and communicated to its users via a trusted channel.
At least, it can be published on the pool's public website.


## 3.4 Reconnecting Downstream Nodes
An upstream stratum node may occasionally request reconnection of its downstream peers to a different host (e.g. due to maintenance reasons, etc.).
This request is per upstream connection and affects all open channels towards the upstream stratum node.

After receiving a request to reconnect, the downstream node MUST run the handshake protocol with the new node as long as its previous connection was also running through a secure cryptographic session state.


## 3.5 Protocol Extensions
Protocol extensions may be defined by using a non-0 `extension_type` field in the message header (not including the `channel_msg` bit).
The value used MUST either be in the range 0x4000 - 0x7fff (inclusive, i.e. have the second-to-most-significant-bit set) denoting an "experimental" extension and not be present in production equipment, or have been allocated for the purpose at [http://stratumprotocol.org](http://stratumprotocol.org).
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
See ChannelEndpointChanged message in Common Protocol Messages for details about how extensions interact with dynamic channel reconfiguration in proxies.


## 3.6 Error Codes
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


## 3.7 Common Protocol Messages
The following protocol messages are common across all of the protocols described in this BIP.


### 3.7.1 SetupConnection (Client -> Server)
Initiates the connection.
This MUST be the first message sent by the client on the newly opened connection.
Server MUST respond with either a `SetupConnection.Success` or `SetupConnection.Error` message.
Clients that are not configured to provide telemetry data to the upstream node SHOULD set `device_id` to 0-length strings.
However, they MUST always set vendor to a string describing the manufacturer/developer and firmware version and SHOULD always set `hardware_version` to a string describing, at least, the particular hardware/software package in use.

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
|                  |           | `protocol` field as its own values/flags.                                              |
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


### 3.7.2 SetupConnection.Success (Server -> Client)
Response to SetupConnection message if the server accepts the connection.
The client is required to verify the set of feature flags that the server supports and act accordingly.

```
+------------+-----------+----------------------------------------------------------------------------------------+
| Field Name | Data Type | Description                                                                            |
+------------+-----------+----------------------------------------------------------------------------------------+
| flags      | U32       | Flags indicating features causing an error                                             |
+------------+-----------+----------------------------------------------------------------------------------------+
| error_code | STR0_255  | Human-readable error code(s), see Error Codes section below                            |
+------------+-----------+----------------------------------------------------------------------------------------+
```

Possible error codes:

- `unsupported-feature-flags`
- `unsupported-protocol`
- `protocol-version-mismatch`


### 3.7.3 ChannelEndpointChanged (Server -> Client)
When a channel’s upstream or downstream endpoint changes and that channel had previously sent messages with **`channel_msg`** bitset of unknown `extension_type`, the intermediate proxy MUST send a **`ChannelEndpointChanged`** message.
Upon receipt thereof, any extension state (including version negotiation and the presence of support for a given extension) MUST be reset and version/presence negotiation must begin again.

```
+------------+-----------+----------------------------------------------------------------------------------------+
| Field Name | Data Type | Description                                                                            |
+------------+-----------+----------------------------------------------------------------------------------------+
| channel_id | U32       | The channel which has changed enpoint                                                  |
+------------+-----------+----------------------------------------------------------------------------------------+
```
