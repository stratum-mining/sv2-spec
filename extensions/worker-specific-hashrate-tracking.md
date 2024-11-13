# Stratum V2 Extension: Worker Specific Hashrate Tracking

## 0. Abstract

This document proposes a Stratum V2 extension to enable mining pools to track individual workers (`user_identity`) within extended channels. By including a mandatory `user_identity` field with a maximum length of 32 bytes in share messages, pools can track worker-specific hashrate even when multiple devices share a single extended channel.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Overview

This extension introduces the `SubmitIdentifiedSharesExtended` message with a mandatory `user_identity` field, which has a maximum length of 32 bytes, enabling mining pools to track individual workers' hashrates more accurately. If the pool supports this extension, clients are required to include `user_identity` in each share submission, ensuring precise worker tracking while preserving the existing channel structure.

### 1.1 Activate Extension

To use this extension, a client sends an `Activate` message. If the pool supports the extension, it responds with `Activate.Success`. If not, the client must stop further attempts.

### 1.2 Bandwidth Consideration

**Warning**: Including `user_identity` in each share submission can lead to an increase in bandwidth usage, particularly in high-frequency mining environments. For instance, with 10 shares submitted per minute (as an example), each share will be larger due to the inclusion of the `user_identity` field. This increase in message size (from **around** 70 bytes to a maximum of **around** 102 bytes) will result in additional bandwidth consumption for **each extended channel opened**.

- **Without `user_identity`**: Each share is approximately 70 bytes.
- **With `user_identity` (32 bytes)**: Each share is approximately 102 bytes.

Considering an average length of 20 bytes for `user_identity`, each share will be approximately 90 bytes.

At 10 shares per minute, this translates to:
- **Maximum increase (32 bytes)**: 102 bytes - 70 bytes = 32 bytes per share.
- **Average increase (20 bytes)**: 90 bytes - 70 bytes = 20 bytes per share.

For 10 shares per minute, the increase in data transmission per **extended channel opened** is as follows:
- **Maximum increase**: 32 bytes * 10 shares = 320 bytes per minute, or 19.2 KB per hour.
- **Average increase**: 20 bytes * 10 shares = 200 bytes per minute, or 12 KB per hour.

This increase in data transmission per extended channel should be considered, especially in environments with a high volume of shares being submitted.

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

Introduces a new message type with `user_identity` to explicitly identify each worker during share submission.

| Field Name      | Data Type | Description                                                                                                                                                                                                                                                                                |
|-----------------|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| channel_id      | U32       | Channel identification                                                                                                                                                                                                                                                                     |
| sequence_number | U32       | Unique sequential identifier of the submit within the channel                                                                                                                                                                                                                              |
| job_id          | U32       | Identifier of the job as provided by NewMiningJob or NewExtendedMiningJob message                                                                                                                                                                                                          |
| nonce           | U32       | Nonce leading to the hash being submitted                                                                                                                                                                                                                                                  |
| ntime           | U32       | The nTime field in the block header. This MUST be greater than or equal to the header_timestamp field in the latest SetNewPrevHash message and lower than or equal to that value plus the number of seconds since the receipt of that message.                                             |
| version         | U32       | Full nVersion field                                                                                                                                                                                                                                                                        |
| extranonce      | B0_32     | Extranonce bytes which need to be added to coinbase to form a fully valid submission (full coinbase = coinbase_tx_prefix + extranonce_prefix + extranonce + coinbase_tx_suffix). The size of the provided extranonce MUST be equal to the negotiated extranonce size from channel opening. |
| user_identity   | STR0_255  | Up to 32 bytes (not including the length byte), unique string identity for the worker                                                                                                                                                                                                      |

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name                     |
|----------------------|-----------------|----------------------------------|
| 0x00                 | 0               | Activate                         |
| 0x01                 | 0               | Activate.Success                 |
| 0x02                 | 1               | SubmitIdentifiedSharesExtended   |
