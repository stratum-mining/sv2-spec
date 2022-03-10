# Data Types Mapping
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
