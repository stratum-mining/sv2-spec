# Stratum V2 Extension: Worker Specific Hashrate Tracking

## 0. Abstract

This document proposes a Stratum V2 extension to enable mining pools to track individual workers (`user_identity`) within extended channels. By including a unique `user_id` field in share messages, pools can track worker-specific hash rate even when multiple devices share a single extended channel.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Overview

This extension enables mining pools to track individual workers (`user_identity`) within shared channels by introducing a `user_id` field within share submission messages. This implementation can be achieved through one of two options: (1) extending the existing `SubmitSharesExtended` message to include `user_id`, or (2) creating a new message, `SubmitIdentifiedSharesExtended`, with `user_id` integrated for explicit worker tracking. Additionally, the extension includes `SetUserIdentity` messages that allow clients and servers to map each `user_id` to a unique `user_identity`, ensuring accurate tracking of worker hashrates across extended channels.

### 1.1 Activate Extension

A client wishing to use this extension sends the `Activate` message. If supported, the pool responds with `Activate.Success`. Otherwise, the client stops further attempts.

---

## 2. Extension Messages

### `Activate` (Client -> Server)

| Field Name | Data Type | Description                                                 |
| ---------- | --------- | ----------------------------------------------------------- |
| request_id | U32       | Unique identifier for pairing the response                  |

### `Activate.Success` (Server -> Client)

| Field Name | Data Type | Description                                                 |
| ---------- | --------- | ----------------------------------------------------------- |
| request_id | U32       | Unique identifier for pairing the response                  |

### `SubmitIdentifiedSharesExtended` (Client -> Server)
Introduces a new message type with `user_id` to explicitly identify each worker during share submission.

| Field Name      | Data Type | Description                                                                                                                                                                                                                                                                                  |
|-----------------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| channel_id      | U32       | Channel identification                                                                                                                                                                                                                                                                       |
| sequence_number | U32       | Unique sequential identifier of the submit within the channel                                                                                                                                                                                                                                |
| job_id          | U32       | Identifier of the job as provided by NewMiningJob or NewExtendedMiningJob message                                                                                                                                                                                                            |
| nonce           | U32       | Nonce leading to the hash being submitted                                                                                                                                                                                                                                                    |
| ntime           | U32       | The nTime field in the block header. This MUST be greater than or equal to the header_timestamp field in the latest SetNewPrevHash message and lower than or equal to that value plus the number of seconds since the receipt of that message.                                               |
| version         | U32       | Full nVersion field                                                                                                                                                                                                                                                                          |
| extranonce      | B0_32     | Extranonce bytes which need to be added to coinbase to form a fully valid submission (full coinbase = coinbase_tx_prefix + extranonce_prefix + extranonce + coinbase_tx_suffix). The size of the provided extranonce MUST be equal to the negotiated extranonce size from channel opening.   |
| user_id         | U32       | Unique ID linked to the worker for this share                                                                                                                                                                                                                                                |

### `SetUserIdentity` (Client -> Server)

The client synchronizes the `user_id` ↔ `user_identity` mapping with the server (Pool).

| Field Name    | Data Type | Description                 |
|---------------|-----------|-----------------------------|
| channel_id    | U32       | Channel identifier          |
| request_id    | U32       | Unique request ID           |
| user_id       | U32       | Unique ID for each worker   |
| user_identity | STR0_255  | Worker identity (name)      |

### `SetUserIdentity.Success` (Server -> Client)

Response indicating the pool has accepted the mapping.

| Field Name    | Data Type | Description                               |
|---------------|-----------|-------------------------------------------|
| channel_id    | U32       | Channel ID                                |
| request_id    | U32       | Original request ID                       |
| user_id       | U32       | Unique ID for each worker                 |

### `SetUserIdentity.Error` (Server -> Client)

Sent if there’s an error with the `user_identity` mapping configuration.

| Field Name    | Data Type   | Description                              |
|---------------|-------------|------------------------------------------|
| channel_id    | U32         | Channel ID                               |
| request_id    | U32         | Original request ID                      |
| user_id       | U32         | Unique ID for each worker                |
| error_code    | STR0_255    | Error reason                             |

Possible error codes:
- `invalid-channel-id`
- `share-from-{user_id}-not-received` - this means that no share associated with that user_id has been received by the server

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name                     |
|----------------------|-----------------|----------------------------------|
| 0x00                 | 0               | Activate                         |
| 0x01                 | 0               | Activate.Success                 |
| 0x02                 | 1               | SubmitIdentifiedSharesExtended   |
| 0x03                 | 1               | SetUserIdentity                  |
| 0x04                 | 1               | SetUserIdentity.Success          |
| 0x05                 | 1               | SetUserIdentity.Error            |

---

This extension defines an operational framework, allowing mining pools to track individual workers effectively within aggregated extended channels in Stratum V2.
