# 4 Protocol Security

Stratum V2 employs a type of encryption scheme called AEAD (authenticated encryption with associated data) to address the security aspects of all communication that occurs between clients and servers.
This provides both confidentiality and integrity for the messages being transferred as encrypted data, as well as providing integrity for associated data which is not encrypted.
Prior to opening any Stratum V2 Connections, clients MUST first initiate the cryptographic session state that is used to encrypt all messages sent between themselves and servers.
Thus, the cryptographic session state is independent of V2 messaging conventions.

At the same time, this specification proposes optional use of a particular handshake protocol based on the **Noise Protocol framework**<sup>[8](#reference-8)</sup>.
The client and server establish secure communication using Diffie-Hellman (DH) key agreement, as described in greater detail in the Authenticated Key Agreement Handshake section below.

Using the handshake protocol to establish secured communication is **optional** on the local network (e.g. local mining devices talking to a local mining proxy).
However, it is **mandatory** for remote access to the upstream nodes, whether they be pool mining services, job declarating services or template distributors.

## 4.1 Motivation for Authenticated Encryption with Associated Data

Data transferred by the mining protocol MUST NOT provide an adversary with information that they can use to estimate the performance of any particular miner. Any intelligence about submitted shares can be directly converted to estimations of a miner’s earnings and can be associated with a particular username. This is unacceptable privacy leakage that needs to be addressed.

## 4.2 Motivation for Using the Noise Protocol Framework

The reasons why Noise Protocol Framework has been chosen are listed below:

- The Framework provides a formalism to describe the handshake protocol that can be verified.
- A custom certificate scheme is now possible (no need to use x509 certificates).

## 4.3 Choice of cryptographic primitives

Noise encrypted session requires Elliptic Curve (EC), Hash function (`HASH()`) and cipher function that supports AEAD mode<sup>[1](#reference-1)</sup>.

This specification describes mandatory cryptographic primitives that each implementation needs to support.
These primitives are chosen so that Noise Encryption layer for Stratum V2 can be implemented using primitives already present in Bitcoin Core project at the time of writing this spec.

### 4.3.1 Elliptic Curve

- Bitcoin's secp256k1 curve<sup>[2](#reference-2)</sup> is used
- Schnorr signature scheme is used as described in BIP340<sup>[3](#reference-3)</sup>

#### 4.3.1.1 EC point encoding remarks

Secp256k1 curve points, i.e. Public Keys, are points with of X- and Y-coordinate.
We serialize them in three different ways, only using the x-coordinate.

1. When signing or verifying a certificate, we use the 32 byte x-only
encoding as defined in BIP 340.<sup>[3](#reference-3)</sup>.

2. When sharing keys during the handshake, whether in plain text or encrypted,
we use the 64 byte ElligatorSwift x-only encoding as defined in BIP324<sup>[7](#reference-7)</sup> under "ElligatorSwift encoding of curve X coordinates". This encoding uses 64-bytes instead of 32-bytes in order to produce a
pseudo-random bytesteam. This is useful because the protocol handshake starts with
each side sending their public key in plain text. Additionally the use of X-only
ElligatorSwift ECDH removes the need to grind or negate private keys.

3. The Authority public key is base58-check encoded as described in 4.7.

Digital signatures are serialized in 64-bytes like in BIP340<sup>[3](#reference-3)</sup>.

Key generation algorithm:

1. generate random 32-byte secret key `sk`
2. let `d' = int(sk)`
3. fail if `d = 0` or `d' > n` where `n` is group order of secp256k1 curve
4. compute `P` as `d'⋅G`
5. drop the Y coordinate and compute (u, t) = XElligatorSwift(P.x)
6. ellswift_pub = bytes(u) || bytes(t)
7. output keypair `(sk, ellswift_pub)`

To perform X-only ECDH we use ellswift_ecdh_xonly(ellswift_theirs, d) as described in BIP324<sup>[7](#reference-7)</sup> under "Shared secret computation". The result is 32 bytes.

No assumption is made about the parity of Y-coordinate. For the purpose of signing
(e.g. certificate) and ECDH (handshake) it is _not_ necessary to "grind"
the private key. The chosen algorithms take care of this by implicitly negating
the key, as if its public key had an even Y-coordinate.

For more information refer to BIP340<sup>[3](#reference-3)</sup> and BIP324<sup>[7](#reference-7)</sup>.

### 4.3.2 Hash function

- `SHA-256()` is used as a `HASH()`

### 4.3.3 Cipher function for authenticated encryption

- Cipher has methods for encryption and decryption for key `k`, nonce `n`, associated_data `ad`, plaintext `pt` and ciphertext `ct`
  - `ENCRYPT(k, n, ad, pt)`
  - `DECRYPT(k, n, ad, ct)`
- ChaCha20 and Poly1305 in AEAD mode<sup>[4](#reference-4)</sup> (ChaChaPoly) is used as a default AEAD cipher

## 4.4 Cryptographic operations

### 4.4.1 CipherState object

Object that encapsulates encryption and decryption operations with underlying AEAD mode cipher functions using 32-byte encryption key `k` and 8-byte nonce `n`.
CipherState has the following interface:

- `InitializeKey(key)`:
  - Sets `k = key`, `n = 0`
- `EncryptWithAd(ad, plaintext)`
  - If `k` is non-empty, performs `ENCRYPT(k, n++, ad, plaintext)` on the underlying cipher function, otherwise returns `plaintext`. The `++` post-increment operator applied to `n` means: "use the current n value, then increment it".
  - Where `ENCRYPT` is an evaluation of `ChaCha20-Poly1305` (IETF variant) with the passed arguments, with nonce `n` encoded as 32 zero bits, followed by a _little-endian_ 64-bit value. Note: this follows the Noise Protocol convention, rather than our normal endian.
- `DecryptWithAd(ad, ciphertext)`
  - If `k` is non-empty performs `DECRYPT(k, n++, ad, plaintext)` on the underlying cipher function, otherwise returns ciphertext. If an authentication failure occurs in `DECRYPT()` then `n` is not incremented and an error is signaled to the caller.
  - Where `DECRYPT` is an evaluation of `ChaCha20-Poly1305` (IETF variant) with the passed arguments, with nonce `n` encoded as 32 zero bits, followed by a _little-endian_ 64-bit value.

### 4.4.2 Handshake Operation

Throughout the handshake process, each side maintains these variables:

- `ck`: **chaining key**. Accumulated hash of all previous ECDH outputs. At the end of the handshake `ck` is used to derive encryption key `k`.
- `h`: **handshake hash**. Accumulated hash of _all_ handshake data that has been sent and received so far during the handshake process
- `e`, `re` **ephemeral keys**. Ephemeral key and remote party's ephemeral key, respectively.
- `s`, `rs` **static keys**. Static key and remote party's static key, respectively.

The following functions will also be referenced:

- `generateKey()`: generates and returns a fresh `secp256k1` keypair

  - Where the object returned by `generateKey` has two attributes:
    - `.public_key`, which returns an abstract object representing the public key
    - `.private_key`, which represents the private key used to generate the public key
  - Where the public_key object also has a single method:
    - `.serializeEllSwift()` that outputs a 64-byte EllSwift encoded serialization of the X-coordinate of EC point (the Y-coordinate is ignored)

- `a || b` denotes the concatenation of two byte strings `a` and `b`

- `HMAC-HASH(key, data)`

  - Applies HMAC defined in `RFC 2104`<sup>[5](#reference-5)</sup>
  - In our case where the key is always 32 bytes, this reduces down to:
    - pad the key with zero bytes to fill the hash block (block length is 64 bytes in case of SHA-256): `k' = k || <zero-bytes>`
    - calculate `temp = SHA-256((k' XOR ipad) || data)` where ipad is repeated 0x36 byte
    - output `SHA-256((k' XOR opad) || temp)` where opad is repeated 0x5c byte

- `HKDF(chaining_key, input_key_material, num_outputs)`: a function defined in `RFC 5869`<sup>[6](#reference-6)</sup>, evaluated with a zero-length `info` field. This document only ever uses `num_outputs = 2`:

  - Sets `temp_key = HMAC-HASH(chaining_key, input_key_material)`
  - Sets `output1 = HMAC-HASH(temp_key, byte(0x01))`
  - Sets `output2 = HMAC-HASH(temp_key, output1 || byte(0x02))`
  - Returns the pair `(output1, output2)`

- `MixKey(input_key_material)`: Executes the following steps:

  - sets `(ck, temp_k) = HKDF(ck, input_key_material, 2)`
  - calls `InitializeKey(temp_k)`

- `MixHash(data)`: Sets `h = HASH(h || data)`

- `EncryptAndHash(plaintext)`:

  - If `k` is non-empty sets `ciphertext = EncryptWithAd(h, plaintext)`, otherwise `ciphertext = plaintext`
  - Calls `MixHash(ciphertext)`
  - returns `ciphertext`

- `DecryptAndHash(ciphertext)`:

  - If `k` is non-empty sets `plaintext = DecryptWithAd(h, ciphertext)`, otherwise `plaintext = ciphertext`
  - Calls `MixHash(ciphertext)`
  - returns `plaintext`

- `ECDH(k, rk)`: performs an Elliptic-Curve Diffie-Hellman operation
  using `k`, which is a   valid `secp256k1` private key, and `rk`, which is a EllSwift
  encoded public key
  - The output is 32 bytes
  - It is a shortcut for performing operation `v2_ecdh` defined in BIP324<sup>[7](#reference-7)</sup>:
    - let `k, ellswift_k` be key pair created by `ellswift_create()` function
    - let `rk` be remote public key **encoded as ellswift**.
    - let `initiator` be bool flag that is **true** if the party performing ECDH initiated the handshake
    - then `ECDH(k, rk) = v2_ecdh(k, ellswift_k, rk, initiator)`

- `v2_ecdh(k, ellswift_k, rk, initiator)`: 
  - let `ecdh_point_x32` = `ellswift_ecdh_xonly(rk, k)`
  - if initiator == true:
    - return `tagged_hash(ellswift_k, rk, ecdh_point_x32)`
    - else return `tagged_hash(rk, ellswift_k, ecdh_point_x32)`
  - **Note that the ecdh result is not commutative with respect to roles! Therefore the initiator flag is needed**

- `ellswift_ecdh_xonly` - see BIP324<sup>[7](#reference-7)</sup>
- `tagged_hash(a, b, c)`:
  - let tag = `SHA256("bip324_ellswift_xonly_ecdh")`
  - return `SHA256(concatenate(tag, tag, a, b, c))`




## 4.5 Authenticated Key Agreement Handshake

The handshake chosen for the authenticated key exchange is an **`Noise_NX`** augmented by server authentication with simple 2 level public key infrastructure.

The complete authenticated key agreement (`Noise NX`) is performed in three distinct steps. The first two exchange one handshake message each. The third step does not send a message.

1. NX-handshake part 1: `-> e`
2. NX-handshake part 2: `<- e, ee, s, es`
3. Server authentication: Initiator validates authenticity of server using `SIGNATURE_NOISE_MESSAGE`

The handshake pattern notation is defined in section 7.1 of the Noise Protocol Framework<sup>[8](#reference-8)</sup>. A payload is implicit at the end of each message pattern (section 3). It is empty for the first handshake message. `SIGNATURE_NOISE_MESSAGE` is sent as the payload of the second handshake message.

Should the decryption (i.e. authentication code validation) fail at any point, the session must be terminated.

### 4.5.1 NX-handshake part 1 `-> e`

Prior to starting first round of NX-handshake, both initiator and responder initializes handshake variables `h` (hash output), `ck` (chaining key) and `k` (encryption key):

1. **hash output** `h = HASH(protocolName)`

- Since `protocolName` more than 32 bytes in length, apply `HASH` to it.
- `protocolName` is official Noise Protocol name: `Noise_NX_Secp256k1+EllSwift_ChaChaPoly_SHA256`
  encoded as an ASCII string

2. **chaining key** `ck = h`
3. **hash output** `h = HASH(h)`
4. **encryption key** `k ` empty

#### 4.5.1.1 Initiator

Initiator generates ephemeral keypair and sends the public key to the responder:

1. initializes empty output buffer
2. generates ephemeral keypair `e`, appends `e.public_key.serializeEllSwift()` to the buffer (64 bytes plaintext EllSwift encoded public key)
3. calls `MixHash(e.public_key)`
4. calls `EncryptAndHash()` with empty payload and appends the ciphertext to the buffer (note that _k_ is empty at this point, so this effectively reduces down to `MixHash()` on empty data)
5. submits the buffer for sending to the responder in the following format

##### Ephemeral public key message:

| Field name      | Description                      |
| --------------- | -------------------------------- |
| ELLSWIFT_PUBKEY | Initiator's ephemeral public key |

Message length: 64 bytes

#### 4.5.1.2 Responder

1. receives ephemeral public key message (64 bytes plaintext EllSwift encoded public key)
2. parses received public key as `re.public_key`
3. calls `MixHash(re.public_key)`
4. calls `DecryptAndHash()` on the remaining bytes, which is the empty payload (note that _k_ is empty at this point, so this effectively reduces down to `MixHash()` on empty data)

### 4.5.2 NX-handshake part 2 `<- e, ee, s, es`

Responder provides its ephemeral, encrypted static public keys and, as the payload, encrypted `SIGNATURE_NOISE_MESSAGE` to the initiator, performs Elliptic-Curve Diffie-Hellman operations.

##### SIGNATURE_NOISE_MESSAGE

| Field Name      | Data Type | Description                                                    |
| --------------- | --------- | -------------------------------------------------------------- |
| version         | U16       | Version of the certificate format (currently MUST be 0)        |
| valid_from      | U32       | Validity start time (unix timestamp)                           |
| not_valid_after | U32       | Signature is invalid after this point in time (unix timestamp) |
| signature       | SIGNATURE | Certificate signature                                          |

Length: 74 bytes

#### 4.5.2.1 Responder

1. initializes empty output buffer
2. generates ephemeral keypair `e`, appends `e.public_key` to the buffer (64 bytes plaintext EllSwift encoded public key)
3. calls `MixHash(e.public_key)`
4. calls `MixKey(ECDH(e.private_key, re.public_key))`
5. appends `EncryptAndHash(s.public_key)` (64 bytes encrypted EllSwift encoded public key, 16 bytes MAC)
6. calls `MixKey(ECDH(s.private_key, re.public_key))`
7. appends `EncryptAndHash(SIGNATURE_NOISE_MESSAGE)` to the buffer
8. submits the buffer for sending to the initiator
9. return pair of CipherState objects, the first for encrypting transport messages from initiator to responder, and the second for messages in the other direction:
   1. sets `temp_k1, temp_k2 = HKDF(ck, zerolen, 2)`
   2. creates two new CipherState objects `c1` and `c2`
   3. calls `c1.InitializeKey(temp_k1)` and `c2.InitializeKey(temp_k2)`
   4. returns the pair `(c1, c2)`

##### Message format of NX-handshake part 2

| Field name              | Description                                                                                                                                                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ELLSWIFT_PUBKEY         | Responder's plaintext ephemeral public key                                                                                                                     |
| ELLSWIFT_PUBKEY         | Responder's encrypted static public key                                                                                                                        |
| MAC                     | Message authentication code for responder's static public key                                                                                                  |
| SIGNATURE_NOISE_MESSAGE | Signed message containing Responder's static key. Signature is issued by authority that is generally known to operate the server acting as the Noise responder |
| MAC                     | Message authentication code for SIGNATURE_NOISE_MESSAGE                                                                                                        |

Message length: 234 bytes

#### 4.5.2.2 Initiator

1. receives NX-handshake part 2 message
2. interprets first 64 bytes as EllSwift encoded `re.public_key`
3. calls `MixHash(re.public_key)`
4. calls `MixKey(ECDH(e.private_key, re.public_key))`
5. decrypts next 80 bytes with `DecryptAndHash()` and stores the results as `rs.public_key` which is **server's static public key** (note that 64 bytes is the public key and 16 bytes is MAC)
6. calls `MixKey(ECDH(e.private_key, rs.public_key)`
7. decrypts next 90 bytes with `DecryptAndHash()` and deserialize plaintext into `SIGNATURE_NOISE_MESSAGE` (74 bytes data + 16 bytes MAC)
8. return pair of CipherState objects, the first for encrypting transport messages from initiator to responder, and the second for messages in the other direction:
   1. sets `temp_k1, temp_k2 = HKDF(ck, zerolen, 2)`
   2. creates two new CipherState objects `c1` and `c2`
   3. calls `c1.InitializeKey(temp_k1)` and `c2.InitializeKey(temp_k2)`
   4. returns the pair `(c1, c2)`

### 4.5.3 Server authentication

During the handshake, initiator receives `SIGNATURE_NOISE_MESSAGE` and **server's static public key**. These parts make up a `CERTIFICATE` signed by an authority whose public key is generally known (for example from pool's website). Initiator confirms the identity of the server by verifying the signature in the certificate.

Currently, `version` MUST be 0. Initiator MUST reject a certificate whose `version` it does not support.

##### CERTIFICATE

| Field Name           | Data Type | Description                                                    | Signed field |
| -------------------- | --------- | -------------------------------------------------------------- | ------------ |
| version              | U16       | Version of the certificate format (currently MUST be 0)        | YES          |
| valid_from           | U32       | Validity start time (unix timestamp)                           | YES          |
| not_valid_after      | U32       | Signature is invalid after this point in time (unix timestamp) | YES          |
| server_public_key    | PUBKEY    | Server's static public key that was used during NX handshake   | YES          |
| authority_public_key | PUBKEY    | Certificate authority's public key that signed this message    | NO           |
| signature            | SIGNATURE | Signature over the serialized fields marked for signing        | NO           |

This message is not sent directly. Instead, it is constructed from SIGNATURE_NOISE_MESSAGE and server's static public
key that are sent during the handshake process

The PUBKEY fields are encoded using only their 32 byte x-coordinate and _not_ with
EllSwift. For the purpose of generating and verifying the certificate, the 64 byte
EllSwift encoded server_public_key can be decoded to its 32 byte x-coordinate.

#### 4.5.3.1 Signature structure

Schnorr signature with _key prefixing_ is used<sup>[3](#reference-3)</sup>

signature is constructed for

- message `m`, where `m` is `HASH` of the serialized fields of the `CERTIFICATE` that are marked for signing, i.e. `m = SHA-256(version || valid_from || not_valid_after || server_public_key)`
- public key `P` that is Certificate Authority

Signature itself is concatenation of an EC point `R` and an integer `s` (note that each item is serialized as 32 bytes array) for which identity `s⋅G = R + HASH(R || P || m)⋅P` holds.

## 4.6 Encrypted stratum message framing

After handshake process is finished, both initiator and responder have CipherState objects for encryption and decryption and after initiator validated server's identity, any subsequent traffic is encrypted and decrypted with `EncryptWithAd()` and `DecryptWithAd()` methods of the respective CipherState objects with zero-length associated data.

Maximum transport message length (ciphertext) for a Noise Protocol message is 65535 bytes.

Since Stratum Message Frame consists of
- fixed length message header: 6 bytes
- variable length serialized stratum message

Stratum Message header and stratum message payload are processed separately.

#### Encrypting stratum message
1. serialize stratum message into a plaintext binary string (payload)
2. prepare the frame header for the Stratum message `message_length` is the length of the plaintext payload.
3. encrypt and concatenate serialized header and payload:
   4. `EncryptWithAd([], header)` - 22 bytes
   5. `EncryptWithAd([], payload)` - variable length encrypted message
4. concatenate resulting header and payload ciphertext

- Note: The `message_length` (payload_length) in the encrypted Stratum message header always reflects the plaintext payload size. The size of the encrypted payload is implicitly understood to be message_length + MAC size for each block. This simplifies the decryption process and ensures clarity in interpreting frame data.

#### Decrypting stratum message
1. read exactly 22 bytes and decrypt into stratum frame or fail
2. The value `frame.message_length` should first be converted to the ciphertext length, and then that amount of data should be read and decrypted into plaintext payload. If decryption fails, the process stops
3. deserialize plaintext payload into stratum message given by `frame.extension_type` and `frame.message_type` or fail


*converting plaintext length to ciphertext length:
```c
#define MAX_CT_LEN 65535
#define MAC_LEN 16
#define MAX_PT_LEN (MAX_CT_LEN - MAC_LEN)

uint pt_len_to_ct_len(uint pt_len) {
        uint remainder;
        remainder = pt_len % MAX_PT_LEN;
        if (remainder > 0) {
                remainder += MAC_LEN;
        }
        return pt_len / MAX_PT_LEN * MAX_CT_LEN + remainder;
}
```


#### Encrypted stratum message frame layout
```
+--------------------------------------------------+-------------------------------------------------------------------+
| Extended Noise header                            | Encrypted stratum-message payload                                 |
+--------------------------------------------------+-------------------+-------------------+---------------------------+
| Header AEAD ciphertext                           | Noise block 1     | Noise block 2     | Last Noise block          |
| 22 Bytes                                         | 65535 Bytes       | 65535 Bytes       | 17 - 65535 Bytes          |
+----------------------------------------+---------+-----------+-------+-----------+-------+---------------+-----------+
| Encrypted Stratum message Header       | MAC     | ct_pld_1  | MAC_1 | ct_pld_2  | MAC_2 | ct_pld_rest   | MAC_rest  |
| 6 Bytes                                | 16 B    | 65519 B   | 16 B  | 65519 B   | 16 B  | 1 - 65519 B   | 16 Bytes  |
+================+==========+============+=========+===========+=======+===========+=======+===============+===========+
| extension_type | msg_type | pld_length | <padd   | pt_pld_1  | <padd | pt_pld_2  | <padd | pt_pld_rest   | <padding> |
| U16            | U8       | U24        |   ing>  | 65519 B   |  ing> | 65519 B   |  ing> | 1 - 65519 B   |           |
+----------------+----------+------------+---------+-------------------------------------------------------------------+

The `pld_length` field in the Encrypted Stratum message Header now consistently represents the plaintext length of the payload.
Serialized stratum-v2 body (payload) is split into 65519-byte chunks and encrypted to form 65535-bytes AEAD ciphertexts,
where `ct_pld_N` is the N-th ciphertext block of payload and `pt_pld_N` is the N-th plaintext block of payload.
```

## 4.7 URL Scheme and Authority Key

Downstream nodes that want to use the above outlined security scheme need to have configured the **Authority Public Key** of the server that they intend to connect to. It is provided by the operator of that server and communicated to its users via a trusted channel.
At least, it can be published on the pool's public website.

The key can be embedded into the mining URL as part of the path.
This key is the Authority Public Key, not the server's static Noise key: the latter is received during the handshake and is never configured by the client (see 4.8).

Authority Public key is [base58-check](https://en.bitcoin.it/wiki/Base58Check_encoding) encoded 32-byte secp256k1 public key (with implicit Y coordinate) prefixed with a LE u16 version prefix, currently `[1, 0]`:

| [1, 0] | 2 bytes prefix |
| ------ | -------------- |
| PUBKEY | 32 bytes authority public key |

This prefix versions the key encoding only and is unrelated to the certificate `version` field.

URL example:

```

stratum2+tcp://thepool.com:34254/9bXiEd8boQVhq7WddEcERUL5tyyJVFYdU8th3HfbNXK3Yw6GRXh

```

### 4.7.1 Test vector:

```

raw_ca_public_key = [118, 99, 112, 0, 151, 156, 28, 17, 175, 12, 48, 11, 205, 140, 127, 228, 134, 16, 252, 233, 185, 193, 30, 61, 174, 227, 90, 224, 176, 138, 116, 85]
prefixed_base58check = "9bXiEd8boQVhq7WddEcERUL5tyyJVFYdU8th3HfbNXK3Yw6GRXh"

```

## 4.8 Key Management and Rotation

Server authentication involves two distinct keys, only one of which is a trust anchor.
Telling them apart determines what an operator can rotate freely and what requires reaching every client.
A client is configured with the authority key of whichever server it connects to, which may be a pool mining service, a job declaration or template distribution server, or a local proxy.

|                                | Authority key                                                                       | Server static key                                                               |
| ------------------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Private half held by           | the server operator                                                                 | the individual server                                                           |
| Public half reaches the client | out of band, through a trusted channel, optionally embedded in the mining URL (4.7) | in band, encrypted, in the second handshake message (4.5.2)                     |
| Client trusts it because       | it was configured before the connection                                             | it is covered by a `CERTIFICATE` signed by the configured authority key (4.5.3) |
| Expected lifetime              | long-lived                                                                          | short-lived, at the discretion of the server operator                           |
| Cost of rotation               | every client has to be reconfigured out of band (4.8.4)                             | none, clients are unaffected (4.8.1)                                            |

This asymmetry is deliberate.
A client that accepted whatever key a server presented at connection time would have confidentiality without authentication: an active attacker on the path can run the handshake with its own keys and sign a certificate with an authority key it generated itself, and a client with nothing to compare it against would accept it.
Server authentication therefore rests entirely on the client already knowing the authority key, which is why no message in this specification carries one (the `CERTIFICATE` of 4.5.3, which lists `authority_public_key`, is never sent).

### 4.8.1 Static and ephemeral key rotation

"Static" here is the Noise framework's name for the key a party holds going into a handshake, as opposed to the ephemeral keypair generated during it (4.4.2). It says nothing about how long that key lives across connections.

The ephemeral key needs no rotation guidance: 4.5.1.1 and 4.5.2.1 generate a fresh ephemeral keypair inside every handshake, so it never persists between connections. Rotating the static key is the remaining case, and it is entirely a server-side decision.

The static key is sent in every handshake and is only ever trusted through its certificate.
A server MAY generate its static key once per deployment, once per process start or once per connection, and MAY replace it at any time.
None of these require any action from clients, as long as every handshake carries a valid certificate over the presented static key, signed by the authority key the client is configured with.

Certificates MAY be signed at handshake time or issued in advance and loaded by the server at startup.
Issuing them in advance is what allows the authority private key to stay off the server.

### 4.8.2 Custody of the authority private key

Section 3.6.5 notes that `Reconnect` intentionally carries no authority public key, so that a compromised server cannot redirect hashrate to an arbitrary server.
That property depends on compromising a server not also yielding the authority private key: whoever holds it can sign a certificate over any static key and impersonate a legitimate server to every client configured with that authority.

The authority private key SHOULD therefore be kept off internet-facing servers, whether offline, in a hardware security module, or behind an internal signing service.
Such a server holds only its static key and a certificate over it.

The authority key is an ordinary secp256k1 key (4.3.1), so an operator MAY derive it from a BIP32<sup>[9](#reference-9)</sup> hierarchy it already keeps secure, under a derivation path dedicated to this purpose and kept apart from any path used for coins.

### 4.8.3 Certificate validity

There is no certificate revocation mechanism, so a leaked static key remains usable until its certificate expires and `not_valid_after` is the only bound on the damage.
It is RECOMMENDED to issue certificates with short validity periods and renew them automatically, rather than issuing certificates that stay valid for years.

`valid_from` and `not_valid_after` are absolute unix timestamps, and are therefore evaluated against the initiator's clock:

- Initiators SHOULD tolerate a small amount of clock skew when checking the validity window.
- Issuers MAY set `valid_from` slightly in the past for the same reason.
- Devices without a reliable clock cannot enforce the window at all. Such a device SHOULD attempt to obtain the current time from a network time source such as NTP before the handshake, and fall back to not enforcing the window only if none is reachable. Implementers targeting such devices should be aware that those devices still get the binding between static key and authority key, but not its expiry.

A client that checks the validity window does so when the certificate is received during the handshake.
A certificate already outside its window at that point is treated as a failed verification, handled as in 4.8.6: the client rejects it and does not proceed with the connection.
An already established session need not be terminated once `not_valid_after` passes.

### 4.8.4 Rotating the authority key

Rotating the authority key is expected to be rare.
In the 2 level public key infrastructure of 4.5 it is the long-lived level and the static key the short-lived one: the authority key signs certificates and never takes part in a session, so its exposure is limited to the signing operation, which 4.8.2 keeps off the servers.
Rotation answers a compromise or a policy, not a schedule.
There is no in-band mechanism for it: as described in 3.6.5, `Reconnect` deliberately cannot point a client at a different authority.
A new authority key reaches clients the same way the first one did, out of band, through the trusted channel described in 4.7.

The recommended procedure is to serve the new authority key on a new endpoint, in parallel with the old one:

1. Bring up a new host or port whose servers present certificates signed by the new authority key. This can be an additional listening port or hostname on the same servers, fronting the same backend, so the cost is one extra listener and a second certificate rather than a second deployment.
2. Publish the new URL through the trusted channel of 4.7. Clients MAY be configured with it in advance as a failover target, so that no device needs to be touched at cutover time.
3. Retire the old endpoint once the hashrate has moved.

Where clients support multiple authority keys (4.8.5), the same rotation is possible on a single endpoint.

A suspected compromise of the authority private key is the exception.
While the old key stays configured on clients, whoever holds it can impersonate a legitimate server, so the overlap period is itself the exposure and an immediate cutover is preferable to a gradual migration.

### 4.8.5 Multiple authority keys

A client MAY be configured with more than one authority public key for the same endpoint, accepting a server's certificate if it verifies against any of them.
This is entirely a client-side matter: the server still presents one certificate signed by one authority, however many keys any client holds, and nothing on the wire changes.
The cost to a client is at most one additional signature verification per configured key, per handshake.

Trusting a set rather than a single key separates distributing an authority key from starting to use it.
An operator can publish its next authority key, or a backup key whose private half never leaves offline storage, long before any server presents a certificate signed by it.
Clients pick it up at their own pace and the operator switches over at a date announced in advance, so rotating on a single endpoint needs no flag day, and a leaked authority key can be replaced without every client having to react within a deadline.

Removing a key remains time-sensitive.
After a compromise, a client stays exposed for as long as the leaked key is still in its set, because a certificate signed by that key keeps verifying.
A rotation distributed through the trusted channel of 4.7 therefore covers both halves: the key to add, and the key to stop trusting.

### 4.8.6 Failed certificate verification

Two failure modes already have rules in this chapter: "Should the decryption (i.e. authentication code validation) fail at any point, the session must be terminated" (4.5), and an initiator "MUST reject a certificate whose `version` it does not support" (4.5.3).
Certificate verification is the remaining case.
As used here, verification fails when the signature does not verify against any authority key the client is configured with, or when a client that checks the validity window (4.8.3) finds the certificate outside it.

A client configured with an authority key SHOULD terminate the connection when verification fails, and fall back to its next configured server.
Continuing anyway is equivalent to running without server authentication: a server whose authority key was rotated without the client learning of it, and an active attacker who substituted their own key, are indistinguishable to the client, because both produce a certificate that does not verify.

Where an implementation offers a way to continue regardless, it is RECOMMENDED that this be an explicit operator opt-in rather than a default, and that it be presented as choosing unauthenticated operation.
Logging the failure and continuing is not a mitigation, as the session is established with an unauthenticated peer either way.

## 4.9 References

1. <a id="reference-1" href="https://web.cs.ucdavis.edu/~rogaway/papers/ad.pdf">https://web.cs.ucdavis.edu/~rogaway/papers/ad.pdf</a>
2. <a id="reference-2" href="https://www.secg.org/sec2-v2.pdf">https://www.secg.org/sec2-v2.pdf</a>
3. <a id="reference-3" href="https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki">https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki</a>
4. <a id="reference-4" href="https://tools.ietf.org/html/rfc8439">https://tools.ietf.org/html/rfc8439</a>
5. <a id="reference-5" href="https://www.ietf.org/rfc/rfc2104.txt">https://www.ietf.org/rfc/rfc2104.txt</a>
6. <a id="reference-6" href="https://tools.ietf.org/html/rfc5869">https://tools.ietf.org/html/rfc5869</a>
7. <a id="reference-7" href="https://github.com/bitcoin/bips/blob/master/bip-0324.mediawiki">https://github.com/bitcoin/bips/blob/master/bip-0324.mediawiki</a>
8. <a id="reference-8" href="https://noiseprotocol.org/noise.html">https://noiseprotocol.org/noise.html</a> (revision 34)
9. <a id="reference-9" href="https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki">https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki</a>
