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
| PUBKEY        | 32                              | Ed25519 public key                                                 |
+---------------+---------------------------------+--------------------------------------------------------------------+
| SIGNATURE     | 2 + LENGTH                      | Ed25519 signature                                                  |
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

Using the handshake protocol to establish secured communication is optional on the local network (e.g. local mining devices talking to a local mining proxy).
However, it is mandatory for remote access to the upstream nodes, whether they be pool mining services, job negotiating services or template distributors.
