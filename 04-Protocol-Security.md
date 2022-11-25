
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
Data transferred by the mining protocol MUST not provide adversary information that they can use to estimate the performance of any particular miner. Any intelligence about submitted shares can be directly converted to estimations of a miner’s earnings and can be associated with a particular username. This is unacceptable privacy leakage that needs to be addressed.


## 4.2 Motivation for Using the Noise Protocol Framework
The reasons why Noise Protocol Framework has been chosen are listed below:

- The Framework provides a formalism to describe the handshake protocol that can be verified.
- A custom certificate scheme is now possible (no need to use x509 certificates).

## 4.3 Choice of cryptographic primitives

Noise encrypted session requires Elliptic Curve (EC), Hash function (`HASH()`) and cipher function that supports AEAD mode<sup>[1](#reference-1)</sup>.

This specification describes mandatory cryptographic primitives that each implementation needs to support.
These primitives are chosen so that Noise Encryption layer for Stratum V2 can be implemented using primitives already present in Bitcoin Core project at the time of writing this spec.

### 4.3.1 Elliptic Curve
* Bitcoin's secp256k1 curve<sup>[2](#reference-2)</sup> is used
* Schnorr signature scheme is used as described in BIP340<sup>[3](#reference-3)</sup>

#### 4.3.1.1 EC point encoding remarks
Secp256k1 curve points, which includes Public Keys and ECDH results, are points with of X- and Y-coordinate, 32-bytes each. There are several possibilities how to serialize them:
1. 64-byte full X- and Y-coordinate serialization for public keys (and ECDH results) and 96 bytes for signatures.
2. 33-byte X-coordinate with 1 parity bit serialization for public keys and similarly 65-byte for signatures.
3. 32-byte X-coordinate only with implicit Y-coordinate for public keys and 64-byte for signatures.

We choose the 32-byte serialization for public key and 64-byte for signatures with implicit Y-coordinate.

The parity of Y-coordinate is always assumed to be even.

Key generation algorithm:
1. generate random 32-byte secret key `sk`
2. let `d' = int(sk)`
3. fail if `d = 0` or `d' > n` where `n` is group order of secp256k1 curve
4. compute `P` as `d'⋅G`
5. drop the Y coordinate and output keypair `(sk, bytes(P.x))`

Such system has the following properties:
* for each keypair `(sk, bytes(P.x))` there is another keypair `(n - sk, bytes(P.x))`, where `n` is group order of secp256k1 curve
* Each result of `ECDH(sk, Q)` is equal to `ECDH(n - sk, Q)` for some EC point `Q` where `n` is group order of secp256k1 curve

These properties don't reduce security.

For more information refer to BIP340<sup>[3](#reference-3)</sup>

### 4.3.2 Hash function
* `SHA-256()` is used as a `HASH()`

### 4.3.3 Cipher function for authenticated encryption
* Cipher has methods for encryption and decryption for key `k`, nonce `n`, associated_data `ad`, plaintext `pt` and ciphertext `ct`
  * `ENCRYPT(k, n, ad, pt)`
  * `DECRYPT(k, n, ad, ct)`
* ChaCha20 and Poly1305 in AEAD mode<sup>[4](reference-4)</sup> (ChaChaPoly) is used as a default AEAD cipher

## 4.4 Cryptographic operations

### 4.4.1 CipherState object
Object that encapsulates encryption and decryption operations with underlying AEAD mode cipher functions using 32-byte encryption key `k` and 8-byte nonce `n`.
CipherState has the following interface:

* `InitializeKey(key)`:
  * Sets `k = key`, `n = 0`
* `EncryptWithAd(ad, plaintext)`
  * If `k` is non-empty, performs `ENCRYPT(k, n++, ad, plaintext)` on the underlying cipher function, otherwise returns `plaintext`
  * Where `ENCRYPT` is an evaluation of `ChaCha20-Poly1305` (IETF variant) or `AES-GCM` with the passed arguments, with nonce `n` encoded as 32 zero bits, followed by a *little-endian* 64-bit value. Note: this follows the Noise Protocol convention, rather than our normal endian.
* `DecryptWithAd(ad, ciphertext)`
  * If `k` is non-empty performs `DECRYPT(k, n++, ad, plaintext)` on the underlying cipher function, otherwise returns ciphertext. If an authentication failure occurs in `DECRYPT()` then `n` is not incremented and an error is signaled to the caller.
  * Where `DECRYPT` is an evaluation of `ChaCha20-Poly1305` (IETF variant) or `AES-GCM` with the passed arguments, with nonce `n` encoded as 32 zero bits, followed by a *little-endian* 64-bit value.

### 4.4.2 Handshake Operation
Throughout the handshake process, each side maintains these variables:

* `ck`: **chaining key**. Accumulated hash of all previous ECDH outputs. At the end of the handshake `ck` is used to derive encryption key `k`.
*  `h`: **handshake hash**. Accumulated hash of _all_ handshake data that has been sent and received so far during the handshake process
* `e`, `re` **ephemeral keys**. Ephemeral key and remote party's ephemeral key, respectively.
* `s`, `rs` **static keys**. Static key and remote party's static key, respectively.

The following functions will also be referenced:

* `generateKey()`: generates and returns a fresh `secp256k1` keypair
  * Where the object returned by `generateKey` has two attributes:
    * `.public_key`, which returns an abstract object representing the public key
    * `.private_key`, which represents the private key used to generate the public key
  * Where the object also has a single method:
    * `.serializeImplicit()` that outputs a 32-byte serialization of the X-coordinate of EC point (implicit Y-coordinate)

* `a || b` denotes the concatenation of two byte strings `a` and `b`

* `HMAC-HASH(key, data)`
  * Applies HMAC defined in `RFC 2104`<sup>[5](#reference-5)
  * In our case where the key is always 32 bytes, this reduces down to:
    * pad the key with zero bytes to fill the hash block (block length is 64 bytes in case of SHA-256): `k' = k || <zero-bytes>`
    * calculate `temp = SHA-256((k' XOR ipad) || data)` where ipad is repeated 0x36 byte
    * output `SHA-256((k' XOR opad) || temp)` where opad is repeated 0x5c byte

* `HKDF(chaining_key, input_key_material, num_output)`: a function defined in `RFC 5869`<sup>[6](#reference-6)</sup>, evaluated with a zero-length `info` field:
  * Sets `temp_key = HMAC-HASH(chaining_key, input_key_material)`
  * Sets `output1 = HMAC-HASH(temp_key, byte(0x01))`
  * Sets `output2 = HMAC-HASH(temp_key, output1 || byte(0x02))`
  * If `num_outputs == 2` then returns the pair `(output1, output2)`
  * Sets `output3 = HMAC-HASH(temp_key, output2 || byte(0x03))`
  * Returns the triple `(output1, output2, output3)`

* `MixKey(input_key_material)`: Executes the following steps:
  * sets `(ck, temp_k) = HKDF(ck, input_key_material, 2)`
  * calls `InitializeKey(temp_k)`

* `MixHash(data)`: Sets `h = HASH(h || data)`

* `EncryptAndHash(plaintext)`:
  * If `k` is non-empty sets `ciphertext = EncryptWithAd(h, plaintext)`, otherwise  `ciphertext = plaintext`
  * Calls `MixHash(ciphertext)`
  * returns `ciphertext`

* `DecryptAndHash(ciphertext)`:
  * If `k` is non-empty sets `plaintext = DecryptWithAd(h, ciphertext)`, otherwise  `plaintext = ciphertext`
  * Calls `MixHash(ciphertext)`
  * returns `plaintext`

* `ECDH(k, rk)`: performs an Elliptic-Curve Diffie-Hellman operation using `k`, which is a valid `secp256k1` private key, and `rk`, which is a valid public key
  * The output is X-coordinate of the resulting EC point


## 4.5 Authenticated Key Agreement Handshake
The handshake chosen for the authenticated key exchange is an **`Noise_NX`** augmented by algorithm negotiation prior to handshake itself and server authentication with simple 2 level public key infrastructure.

The complete authenticated key agreement (`Noise NX`) is performed in five distinct steps (acts).

1. NX-handshake part 1: `-> e`
2. NX-handshake part 2: `<- e, ee, s, es, SIGNATURE_NOISE_MESSAGE`
3. Server authentication: Initiator validates authenticity of server using from `SIGNATURE_NOISE_MESSAGE`
4. Cipher upgrade part 1: Initiator provides list of alternative aead-ciphers that it supports
5. Cipher upgrade part 2: Responder confirms or dismisses upgrade to a different aead-cipher

Should the decryption (i.e. authentication code validation) fail at any point, the session must be terminated.

### 4.5.1 Handshake Act 1: NX-handshake part 1 `-> e`

Prior to starting first round of NX-handshake, both initiator and responder initializes handshake variables `h` (hash output), `ck` (chaining key) and `k` (encryption key):

1. **hash output** `h = protocolName || <zero-padding>` or `h = HASH(protocolName)`
  * If `protocolName` is less than or equal to 32 bytes in length, use `protocolName` with zero bytes appended to make 32 bytes. Otherwise, apply `HASH` to it.
  * `protocolName` is official noise protocol name such as `Noise_NX_secp256k1_ChaChaPoly_SHA256` encoded as an ASCII string
2. **chaining key** `ck = h`
3. **hash output** `h = HASH(h)`
4. **encryption key** `k ` empty

#### 4.5.1.1 Initiator
Initiator generates ephemeral keypair and sends the public key to the responder:

1. initializes empty output buffer
2. generates ephemeral keypair `e`, appends `e.public_key` to the buffer (32 bytes plaintext public key)
3. calls `MixHash(e.public_key)`
4. calls `EncryptAndHash()` with empty payload and appends the ciphertext to the buffer (note that *k* is empty at this point, so this effectively reduces down to `MixHash()` on empty data)
5. submits the buffer for sending to the responder in the following format

```
Ephemeral public key message:
+---------------+------------------------------------------------------------------------------------------------------+
| PUBKEY        |  Initiator's ephemeral public key                                                                    |
+---------------+------------------------------------------------------------------------------------------------------+

Message length: 32 bytes
```

#### 4.5.1.2 Responder
1. receives ephemeral public key message (32 bytes plaintext public key)
2. parses received public key as `re.public_key`
3. calls `MixHash(re.public_key)`
4. calls `DecryptAndHash()` on remaining bytes (i.e. on empty data with empty *k*, thus effectively only calls `MixHash()` on empty data)

### 4.5.2 Handshake Act 2: NX-handshake part 2 `<- e, ee, s, es, SIGNATURE_NOISE_MESSAGE`

Responder provides its ephemeral, encrypted static public keys and encrypted `SIGNATURE_NOISE_MESSAGE` to the initiator, performs Elliptic-Curve Diffie-Hellman operations.

```
SIGNATURE_NOISE_MESSAGE
+-----------------+-----------+----------------------------------------------------------------------------------------+
| Field Name      | Data Type | Description                                                                            |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| version         | U16       | Version of the certificate format                                                      |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| valid_from      | U32       | Validity start time (unix timestamp)                                                   |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| not_valid_after | U32       | Signature is invalid after this point in time (unix timestamp)                         |
+-----------------+-----------+----------------------------------------------------------------------------------------+
| signature       | SIGNATURE | Certificate signature                                                                  |
+-----------------+-----------+----------------------------------------------------------------------------------------+

Length: 74 bytes
```


#### 4.5.2.1 Responder
1. initializes empty output buffer
2. generates ephemeral keypair `e`, appends `e.public_key` to the buffer (32 bytes plaintext public key)
3. calls `MixHash(e.public_key)`
4. calls `MixKey(ECDH(e.private_key, re.public_key))`
5. appends `EncryptAndHash(s.public_key)` (32 bytes encrypted public key, 16 bytes MAC)
6. calls `MixKey(ECDH(s.private_key, re.public_key))`
7. appends `EncryptAndHash(SIGNATURE_NOISE_MESSAGE)` to the buffer
8. submits the buffer for sending to the initiator
9. return pair of CipherState objects, the first for encrypting transport messages from initiator to responder, and the second for messages in the other direction:
   1. sets `temp_k1, temp_k2 = HKDF(ck, zerolen, 2)`
   2. creates two new CipherState objects `c1` and `c2`
   3. calls `c1.InitializeKey(temp_k1)` and `c2.InitializeKey(temp_k2)`
   4. returns the pair `(c1, c2)`

```
Message format of NX-handshake part 2 
+-------------------------+--------------------------------------------------------------------------------------------+
| PUBKEY                  |  Responder's plaintext ephemeral public key                                                |
+-------------------------+--------------------------------------------------------------------------------------------+
| PUBKEY                  |  Responder's encrypted static public key                                                   |
+-------------------------+--------------------------------------------------------------------------------------------+
| MAC                     |  Message authentication code for responder's static public key                             |
+-------------------------+--------------------------------------------------------------------------------------------+
| SIGNATURE_NOISE_MESSAGE |  Signed message containing Responder's static key. Signature is issued by authority that   |
|                         |  is generally known to operate the server acting as the noise responder                    |
+-------------------------+--------------------------------------------------------------------------------------------+
| MAC                     |  Message authentication code for SIGNATURE_NOISE_MESSAGE                                   |
+-------------------------+--------------------------------------------------------------------------------------------+

Message length: 170 bytes
```

#### 4.5.2.2 Initiator
1. receives NX-handshake part 2 message
2. interprets first 32 bytes as `re.public_key`
3. calls `MixHash(re.public_key)`
4. calls `MixKey(ECDH(e.private_key, re.public_key))`
5. decrypts next 48 bytes with `DecryptAndHash()` and stores the results as `rs.public_key` which is **server's static public key** (note that 32 bytes is the public key and 16 bytes is MAC)
6. calls `MixKey(ECDH(e.private_key, rs.public_key)`
7. decrypts next 90 bytes with `DecryptAndHash()` and deserialize plaintext into `SIGNATURE_NOISE_MESSAGE` (74 bytes data + 16 bytes MAC)
9. return pair of CipherState objects, the first for encrypting transport messages from initiator to responder, and the second for messages in the other direction:
   1. sets `temp_k1, temp_k2 = HKDF(ck, zerolen, 2)`
   2. creates two new CipherState objects `c1` and `c2`
   3. calls `c1.InitializeKey(temp_k1)` and `c2.InitializeKey(temp_k2)`
   4. returns the pair `(c1, c2)`

### 4.5.3 Server authentication
During the handshake, initiator receives `SIGNATURE_NOISE_MESSAGE` and **server's static public key**. These parts make up a `CERTIFICATE` signed by an authority whose public key is generally known (for example from pool's website). Initiator confirms the identity of the server by verifying the signature in the certificate.

```
CERTIFICATE
+----------------------+-----------+------------------------------------------------------------------+----------------+
| Field Name           | Data Type | Description                                                      |  Signed field  |
+----------------------+-----------+------------------------------------------------------------------+----------------+
| version              | U16       | Version of the certificate format                                |  YES           |
+----------------------+-----------+------------------------------------------------------------------+----------------+
| valid_from           | U32       | Validity start time (unix timestamp)                             |  YES           |
+----------------------+-----------+------------------------------------------------------------------+----------------+
| not_valid_after      | U32       | Signature is invalid after this point in time (unix timestamp)   |  YES           |
+----------------------+-----------+------------------------------------------------------------------+----------------+
| server_public_key    | PUBKEY    | Server's static public key that was used during NX handshake     |  YES           |
+======================+===========+==================================================================+================+
| authority_public_key | PUBKEY    | Certificate authority's public key that signed this message      |  NO            |
+----------------------+-----------+------------------------------------------------------------------+----------------+
| signature            | SIGNATURE | Signature over the serialized fields marked for signing          |  NO            |
+----------------------+-----------+------------------------------------------------------------------+----------------+

This message is not sent directly. Instead, it is constructed from SIGNATURE_NOISE_MESSAGE and server's static public 
key that are sent during the handshake process
```

#### 4.5.3.1 Signature structure
Schnorr signature with *key prefixing* is used<sup>[3](#reference-3)</sup>

signature is constructed for
* message `m`, where `m` is `HASH` of the serialized fields of the `CERTIFICATE` that are marked for signing, i.e. `m = SHA-256(version || valid_from || not_valid_after || server_public_key)`
* public key `P` that is Certificate Authority

Signature itself is concatenation of an EC point `R` and an integer `s` (note that each item is serialized as 32 bytes array) for which identity `s⋅G = R + HASH(R || P || m)⋅P` holds.

### 4.5.4 Cipher upgrade part 1: `-> AEAD_CIPHERS`

Initiator provides list of AEAD ciphers other than ChaChaPoly that it supports

```
+----------------------+-----------------------------------------------------------------------------------------------+
| SEQ0_32[u32]         |  List of AEAD cipher functions other than ChaChaPoly that the client supports                 |
+----------------------+-----------------------------------------------------------------------------------------------+

Message length: 1 + *n* * 4 bytes, where n is the length byte of the SEQ0_32 field, at most 129

possible cipher codes:
+----------------------+-----------------------------------------------------------------------------------------------+
| cipher code          | Cipher description                                                                            |
+----------------------+-----------------------------------------------------------------------------------------------+
| 0x47534541 (b"AESG") | AES-256 with with GCM from [7]                                                                |
+----------------------+-----------------------------------------------------------------------------------------------+
```
[\[7\]](#reference-7) - Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC


### 4.5.5 Cipher upgrade part 2: `<- CIPHER_CHOICE`

Responder acknowledges receiving `AEAD_CIPHERS` message with `CIPHER_CHOICE`. There are two possible cases
1. `CIPHER_CHOICE` is empty: In this case continue using current established encrypted session
2. `CIPHER_CHOICE` is non-empty - Restart encrypted session using the new AEAD-cipher

```
CIPHER_CHOICE
+---------------------+------------------------------------------------------------------------------------------------+
| OPTION[u32]         |  Request to upgrade to a given AEAD-cipher                                                     |
+---------------------+------------------------------------------------------------------------------------------------+

Message length: 1 or 5 bytes
```

#### 4.5.5.1 Upgrade to a new AEAD-cipher

If the server provides a non-empty `CIPHER_CHOICE`:
1. Both initiator and responder create a new pair of CipherState objects with the negotiated cipher for encrypting transport messages from initiator to responder and in the other direction respectively
2. New keys `key_new` are derived from the original CipherState keys `key_orig` by taking the first 32 bytes from `ENCRYPT(key_orig, maxnonce, zero_len, zeros)` using the negotiated cipher function where `maxnonce` is 2<sup>64</sup> - 1, `zerolen` is a zero-length byte sequence, and `zeros` is a sequence of 32 bytes filled with zeros. (see `Rekey(k)` function<sup>[8](#reference-8)</sup>)
3. New CipherState objects are reinitialized: `InitializeKey(key_new)`.

### 4.5.6 Transport message encryption and format

After handshake process is finished, both initiator and responder have CipherState objects for encryption and decryption and after initiator validated server's identity, any subsequent traffic is encrypted and decrypted with `EncryptWithAd()` and `DecryptWithAd()` methods of the respectrive CipherState objects with zero-length associated data.

Ciphertext is sent in `NOISE_FRAME` over the wire.
```
NOISE_FRAME
+-------------+-----------+--------------------------------------------------------------------------------------------+
| Field Name  | Data Type | Description                                                                                |
+-------------+-----------+--------------------------------------------------------------------------------------------+
| ciphertext  | B0_64K    | AEAD ciphertext including 16 bytes MAC                                                     |
+-------------+-----------+--------------------------------------------------------------------------------------------+
Message length: <Plaintext length> + 18 bytes = <Plaintext length> + <MAC length> + <Type length prefix>

Maximum message length = 65537 bytes
Maximum ciphertext length = 65535 bytes
Maximum plaintext length 65519 bytes
```


Note that in regard to Stratum V2 message, `NOISE_FRAME` doesn't necessarily need to contain to exactly one encrypted Stratum message. Ciphertext payload may contain multiple subsequent messages or even only partial message. Examples:
* `OpenStandardMiningChannelSuccess` followed immediately with `NewMiningJob`
* Arbitrary message containing `B0_16M` type, since the noise ciphertext can be at most `2**16 - 1 == 65535` bytes long


## 4.6 URL Scheme and Pool Authority Key
Downstream nodes that want to use the above outlined security scheme need to have configured the **Pool Authority Public Key** of the pool that they intend to connect to. It is provided by the target pool and communicated to its users via a trusted channel.
At least, it can be published on the pool's public website.


The key can be embedded into the mining URL as part of the path.

Authority Public key is [base58-check](https://en.bitcoin.it/wiki/Base58Check_encoding) encoded 32-byte secp256k1 public key (with implicit Y coordinate) prefixed with a LE u16 version prefix, currently `[1, 0]`:

```
+--------------+-------------------------------------------------------------------------------------------------------+
| [1, 0]       |  2 bytes prefix                                                                                       |
+--------------+-------------------------------------------------------------------------------------------------------+
| PUBKEY       |  32 bytes authority public key                                                                        |
+--------------+-------------------------------------------------------------------------------------------------------+
```

URL example:

```
stratum2+tcp://thepool.com/9bXiEd8boQVhq7WddEcERUL5tyyJVFYdU8th3HfbNXK3Yw6GRXh
```

### 4.6.1 Test vector:

```
raw_ca_public_key =  [118, 99, 112, 0, 151, 156, 28, 17, 175, 12, 48, 11, 205, 140, 127, 228, 134, 16, 252, 233, 185, 193, 30, 61, 174, 227, 90, 224, 176, 138, 116, 85]
prefixed_base58check = "9bXiEd8boQVhq7WddEcERUL5tyyJVFYdU8th3HfbNXK3Yw6GRXh"
```


## 4.7 References

1. <a id="reference-1"> https://web.cs.ucdavis.edu/~rogaway/papers/ad.pdf</a>
2. <a id="reference-2"> https://www.secg.org/sec2-v2.pdf</a>
3. <a id="reference-3"> https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki</a>
4. <a id="reference-4"> https://tools.ietf.org/html/rfc8439</a>
5. <a id="reference-5"> https://www.ietf.org/rfc/rfc2104.txt</a>
6. <a id="reference-6"> https://tools.ietf.org/html/rfc5869</a>
7. <a id="reference-7"> https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf</a>
8. <a id="reference-8"> https://noiseprotocol.org/noise.html#cipher-functions</a>
