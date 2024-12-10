# Stratum V2 Extension: Extensions Negotiation

## 0. Abstract

This document defines a Stratum V2 extension to negotiate support for other protocol extensions between clients and servers.

The mechanism allows clients to request support for a list of extensions immediately after the `SetupConnection` message exchange. The server responds with either:
- `RequestExtensions.Success`, listing the supported extensions.
- `RequestExtensions.Error`, listing the unsupported extensions.

This negotiation ensures that both parties can establish a common set of features before exchanging further protocol messages.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Overview

### 1.1 Negotiating Extensions

After the successful `SetupConnection` exchange, clients MUST send a `RequestExtensions` message to indicate the extensions they wish to use. The server responds with:
- `RequestExtensions.Success`, confirming which extensions are supported.
- `RequestExtensions.Error`, identifying unsupported extensions.

Clients MUST NOT use any features from extensions that are not confirmed as supported by the server.

#### Message Exchange Example

1. **Connection Setup**:
    ```
    Client --- SetupConnection (connection details) ---> Server
    Client <--- SetupConnection.Success (connection accepted) ---- Server
    ```

2. **Extension Negotiation**:
    ```
    Client --- RequestExtensions (list of requested U16) ---> Server
    ```

3. **Server Response**:
    - If successful:
      ```
      Client <--- RequestExtensions.Success (list of supported U16) ---- Server
      ```
    - If an error occurs:
      ```
      Client <--- RequestExtensions.Error (list of unsupported U16) ---- Server
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

| Field Name             | Data Type    | Description                                   |
|------------------------|--------------|-----------------------------------------------|
| request_id             | U16          | Unique identifier for pairing the response.  |
| unsupported_extensions | SEQ0_64K[U16]| List of unsupported extension identifiers. |

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
    - Servers MUST respond with `RequestExtensions.Error` if none of the requested extensions are supported.
    - Servers MAY include an empty `unsupported_extensions` field in the error message if no extensions are explicitly unsupported.

2. **Ordering**:
    - The `RequestExtensions` message MUST be sent immediately after `SetupConnection.Success` and before any other protocol-specific messages.

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
