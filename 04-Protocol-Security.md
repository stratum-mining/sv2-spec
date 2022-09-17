
# 4 Protocol Security
Stratum V2 employs a type of encryption scheme called AEAD (authenticated encryption with associated data) to address the security aspects of all communication that occurs between clients and servers.
This provides both confidentiality and integrity for the ciphertexts (i.e. encrypted data) being transferred, as well as providing integrity for associated data which is not encrypted.
Prior to opening any Stratum V2 channels for mining, clients MUST first initiate the cryptographic session state that is used to encrypt all messages sent between themselves and servers.
Thus, the cryptographic session state is independent of V2 messaging conventions.

At the same time, this specification proposes optional use of a particular handshake protocol based on the **[Noise Protocol framework](https://noiseprotocol.org/noise.html)**.
The client and server establish secure communication using Diffie-Hellman (DH) key agreement, as described in greater detail in the Authenticated Key Agreement Handshake section below.

Using the handshake protocol to establish secured communication is **optional** on the local network (e.g. local mining devices talking to a local mining proxy).
However, it is **mandatory** for remote access to the upstream nodes, whether they be pool mining services, job negotiating services or template distributors.


## 4.1 Motivation for Authenticated Encryption with Associated Data
Data transferred by the mining protocol MUST not provide adversary information that they can use to estimate the performance of any particular miner.
Any intelligence about submitted shares can be directly converted to estimations of a miner’s earnings and can be associated with a particular username.
This is unacceptable privacy leakage that needs to be addressed.


## 4.2 Motivation for Using the Noise Protocol Framework
The reasons why Noise Protocol Framework has been chosen are listed below:

- The Framework pushes to use new, modern cryptography.
- The Framework provides a formalism to describe the handshake protocol that can be verified.
- There is no legacy overhead.
- It is difficult to get wrong.
- Noise Explorer provides code generators for popular programming languages (e.g. Go, Rust).
- We can specify no flexibility (i.e. fewer degrees of freedom), helping ensure standardization of the supported ciphersuite(s).
- A custom certificate scheme is now possible (no need to use x509 certificates).


## 4.3 Authenticated Key Agreement Handshake
The handshake chosen for the authenticated key exchange is **`Noise_NX`** as it
provides authentication of the server side and does not require authentication of the initiator (client).
Server authentication is achieved implicitly via a series of Elliptic-Curve Diffie-Hellman (ECDH) operations followed by a MAC check.

The authenticated key agreement (`Noise NX`) is performed in three distinct steps (acts).
1. Algorithm negotiation: Initiator provides a list of supported algorithms to the responder; responder chooses one and confirms its choice to the initiator. Both initiator and responder commit both messages into the noise Prologue. If initiator's and responder's prologue don't match, subsequent handshake fails.
2. Ephemeral and static key exchange followed by ECDH: keying material is sent to the other party; an ECDH is performed,
   with the result mixed into the current set of encryption keys (`ck` the chaining key and `k` the encryption key)
3. Server authentication with Signature Noise Message: Initiator verifies the SIGNATURE_NOISE_MESSAGE that it received
   in previous step as a handshake payload

The mixing of ECDH outputs into a hash digest forms an incremental DoubleDH handshake.

Using the language of the Noise Protocol, **`e`** and **`s`** (both public keys with `**e**` being the **ephemeral key** and `**s**` being the **static key**) indicate possibly encrypted keying material, and **`es`**, **`ee`**, and **`se`** each indicate an ECDH operation between two keys.
The handshake is laid out as follows:

```
    Negotiation part:
        -> [suggested algorithms]
        <- choice
    
    prologue: [suggested algorithms] + choice
    
    Noise_NX part:
        -> e
        <- e, ee, s, es, SIGNATURE_NOISE_MESSAGE
```

The last handshake message is followed by a `SIGNATURE_NOISE_MESSAGE`.
Using this additional message allows us to authenticate the stratum server to the downstream node.
The certificate implements a simple 2 level public key infrastructure.

The main idea is that each server operator has a long-term authority keypair and each stratum-server is equipped with a
certificate signed by the authority private key that confirms its identity to the clients.
The certificate has time limited validity and is signed by the central pool authority.

## 4.4 Noise message framing
Every message that is sent over the wire as part of a handshake or already an established session is prefixed with payload
length as a two-bytes little endian u16 number

```
+----------------------------+-------------------------------------------------------------------+
| length prefix [2 Bytes]    |  Handshake message or encrypted message                           |
+----------------------------+-------------------------------------------------------------------+
```


## 4.5 Signature Noise Message
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


## 4.6 Certificate Format
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
| authority_public_key | PUBKEY    | Public key used for verfication of the signature                   | NO           |
+----------------------+-----------+--------------------------------------------------------------------+--------------+
| signature            | SIGNATURE | ED25519                                                            | NO           |
+----------------------+-----------+-----------------------------------------------------------------------------------+
```


## 4.7 URL Scheme and Pool Authority Key
Downstream nodes that want to use the above outlined security scheme need to have configured the **Pool Authority Key** of the pool that they intend to connect to.
The key can be embedded into the mining URL as part of the path.
E.g.:

```
stratum2+tcp://thepool.com/u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt
```

The "**`u95GEReVMjK6k5YqiSFNqqTnKU4ypU2Wm8awa6tmbmDmk1bWt`**" is the public key in [base58-check](https://en.bitcoin.it/wiki/Base58Check_encoding) encoding.
It is provided by the target pool and communicated to its users via a trusted channel.
At least, it can be published on the pool's public website.
