# Stratum V2 Extension: Extensions Negotiation

## 0. Abstract

This document defines a Stratum V2 extension to negotiate support for other protocol extensions between clients and servers.

The mechanism allows either clients or servers to initiate a request for extension support immediately after the `SetupConnection` message exchange. The receiving party responds with either:
- `RequestExtensions.Success`, listing the supported extensions.
- `RequestExtensions.Error`, listing the unsupported extensions and extensions required by the receiver.

This negotiation ensures that both parties can establish a common set of features before exchanging further protocol messages.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Overview

### 1.1 Negotiating Extensions

After the successful SetupConnection exchange, either party (client or server) MAY send a RequestExtensions message to indicate the extensions they wish to use. The receiving party responds with:
- `RequestExtensions.Success`, confirming which extensions are supported.
- `RequestExtensions.Error`, identifying unsupported extensions and required extensions from the responder.

Initiators MUST NOT use any features from extensions that are not confirmed as supported by the receiver.

#### Message Exchange Example

- **Connection Setup**:
    ```
    Client --- SetupConnection (connection details) ---> Server
    Client <--- SetupConnection.Success (connection accepted) ---- Server
    ```

- **Extension Negotiation (Client-Initiated)**:
    ```
    Client --- RequestExtensions (list of requested U16) ---> Server
   
    Server Response:
    If successful:
    Client <--- RequestExtensions.Success (list of supported U16) ---- Server

    If an error occurs:
    Client <--- RequestExtensions.Error (unsupported U16, requested U16) ---- Server
    ```

- **Extension Negotiation (Server-Initiated)**:
    ```
    Server --- RequestExtensions (list of requested U16) ---> Client
  
    Client Response:
    If successful:
    Server <--- RequestExtensions.Success (list of supported U16) ---- Client

    If an error occurs:
    Server <--- RequestExtensions.Error (unsupported U16, requested U16) ---- Client
    ```

---

## 2. Messages Defined by This Extension

### `RequestExtensions` (Client -> Server)

| Field Name           | Data Type    | Description                                   |
|----------------------|--------------|-----------------------------------------------|
| request_id           | U16          | Unique identifier for pairing the response.  |
| requested_extensions | SEQ0_64K[U16]| List of requested extension identifiers.     |

### `RequestExtensions.Success` (Server -> Client)

| Field Name           | Data Type    | Description                                   |
|----------------------|--------------|-----------------------------------------------|
| request_id           | U16          | Unique identifier for pairing the response.  |
| supported_extensions | SEQ0_64K[U16]| List of supported extension identifiers.     |

### `RequestExtensions.Error` (Server -> Client)

| Field Name             | Data Type    | Description                                                                               |
|------------------------|--------------|-------------------------------------------------------------------------------------------|
| request_id             | U16          | Unique identifier for pairing the response.                                               |
| unsupported_extensions | SEQ0_64K[U16]| List of unsupported extension identifiers.                                                |
| requested_extensions   | SEQ0_64K[U16]| List of extension identifiers the receiver requires but were not requested by the sender. |

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name              |
|----------------------|-----------------|---------------------------|
| 0x00                 | 0               | RequestExtensions         |
| 0x01                 | 0               | RequestExtensions.Success |
| 0x02                 | 0               | RequestExtensions.Error   |

---

## 4. Implementation Notes

1. **Error Handling**:
    - Receivers MUST respond with `RequestExtensions.Error` if none of the requested extensions are supported.
    - If the receiver **requires** certain extensions but they were not included in the request, it MUST list them in the `requested_extensions` field of `RequestExtensions.Error`.

2. **Ordering**:
    - The `RequestExtensions` message MUST be sent immediately after `SetupConnection.Success` and before any other protocol-specific messages.
    - The response to `RequestExtensions` MUST be received before proceeding with any further protocol-specific messages.

#### 3. **Backward Compatibility**:
- **Server Behavior**:
   - Servers that do not support this extension will ignore the `RequestExtensions` message, potentially leading to a connection timeout.

- **Client Behavior**:
   - Clients MUST NOT send any further protocol-specific messages until they receive a `RequestExtensions.Success` or `RequestExtensions.Error` response.
   - If the client does not receive a response within a reasonable timeout period (e.g., X seconds, where X is implementation-defined), it SHOULD close the connection and report the timeout as an error.

This ensures clients can handle servers that do not implement extensions negotiation gracefully while avoiding indefinite blocking.

4. **Example Use Case**:
   A client requesting support for extensions `0x0002` and `0x0003`:
   ```
   Client --- RequestExtensions [0x0002, 0x0003] ---> Server  
   Client <--- RequestExtensions.Success [0x0002] ---- Server
   ```
   The client now knows that extension `0x0003` is not supported and must adapt its behavior accordingly.


5. **Example Use Case with Server Requesting Extensions**:
   A server requiring extension `0x0005`, but the client did not include it in its request:
   ```
   Client --- RequestExtensions [0x0002, 0x0003] ---> Server  
   Client <--- RequestExtensions.Error [unsupported: 0x0003, requested: 0x0005] ---- Server
   ```
   The client now knows that the server requires extension `0x0005` and MAY choose to retry with a modified request.