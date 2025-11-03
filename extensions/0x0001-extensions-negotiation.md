# Stratum V2 Extension: Extensions Negotiation

## 0. Abstract

This document defines a Stratum V2 extension to negotiate support for other protocol extensions between clients and servers.

The mechanism allows clients to request support for a list of extensions immediately after the `SetupConnection` message exchange. The server responds with either:
- `RequestExtensions.Success`, listing the supported extensions.
- `RequestExtensions.Error`, listing the unsupported extensions and extensions required by the receiver.

This negotiation ensures that both parties can establish a common set of features before exchanging further protocol messages.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Overview

### 1.1 Negotiating Extensions

After the successful SetupConnection exchange, clients MUST send a `RequestExtensions` message to indicate the extensions they wish to use. The server responds with:
- `RequestExtensions.Success`, confirming which extensions are supported.
- `RequestExtensions.Error`, identifying unsupported extensions and required extensions from the responder.

Clients MUST NOT use any features from extensions that are not confirmed as supported by the server.

#### Message Exchange Example

- **Connection Setup**:
    ```
    Client --- SetupConnection (connection details) ---> Server
    Client <--- SetupConnection.Success (connection accepted) ---- Server
    ```

- **Extension Negotiation**:
    ```
    Client --- RequestExtensions (list of requested U16) ---> Server
   
    Server Response:
    If successful:
    Client <--- RequestExtensions.Success (list of supported U16) ---- Server

    If an error occurs:
    Client <--- RequestExtensions.Error (unsupported U16, requested U16) ---- Server
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

| Field Name             | Data Type    | Description                                                                             |
|------------------------|--------------|-----------------------------------------------------------------------------------------|
| request_id             | U16          | Unique identifier for pairing the response.                                             |
| unsupported_extensions | SEQ0_64K[U16]| List of unsupported extension identifiers.                                              |
| required_extensions       | SEQ0_64K[U16]| List of extension identifiers the server requires but were not requested by the client. |

---

## 3. Message Types

| Message Type (8-bit) | channel_msg_bit | Message Name              |
|----------------------|-----------------|---------------------------|
| 0x00                 | 0               | RequestExtensions         |
| 0x01                 | 0               | RequestExtensions.Success |
| 0x02                 | 0               | RequestExtensions.Error   |

**Note on Message Framing:** All messages defined by this extension MUST have `extension_type = 0x0001` in their message frame headers, as this extension introduced and defined these messages. For more details on `extension_type` field usage, see [Section 3.4.1 Extension Type Field Usage](../03-Protocol-Overview.md#341-extension-type-field-usage) in the Protocol Overview.

---

## 4. Implementation Notes

1. **Error Handling**:
    - Servers MUST respond with `RequestExtensions.Error` if none of the requested extensions are supported.
    - If the server **requires** certain extensions but they were not included in the request, it MUST list them in the `requested_extensions` field of `RequestExtensions.Error`.

2. **Ordering**:
    - The `RequestExtensions` message MUST be sent immediately after `SetupConnection.Success` and before any other protocol-specific messages.
    - The response to `RequestExtensions` MUST be received before proceeding with any further protocol-specific messages.

#### 3. **Backward Compatibility**:
- **Server Behavior**:
   - Servers that do not support this extension will ignore the `RequestExtensions` message.

- **Client Behavior**:
   - Clients MUST NOT send any further extension-specific messages until they receive a `RequestExtensions.Success` or `RequestExtensions.Error` response.
   - Clients MAY implement the following timeout and reconnection strategy:
     1. After sending `RequestExtensions`, wait for a timeout of 2x the initial connection time
     2. If no response is received within this timeout:
        - Reconnect to the same server
        - Attempt the extension negotiation again
     3. If still no response after 5x the initial connection time:
        - Reconnect one final time
        - Proceed without any extensions
     4. If the total connection time exceeds approximately 1 second:
        - Consider switching to a fallback pool
   - This strategy ensures that:
     - The first reconnection serves as a basic connectivity check
     - The total connection time remains reasonable for mining operations
     - Clients can gracefully fallback to non-extension operation
     - Users can switch to alternative pools if connection times are too high

This ensures clients can handle servers that do not implement extensions negotiation gracefully while maintaining reasonable connection times for mining operations.

4. **Example Use Case**:
   A client requesting support for extensions `0x0002` and `0x0003`:
   ```
   Client --- RequestExtensions [0x0002, 0x0003] ---> Server  
   Client <--- RequestExtensions.Success [0x0002] ---- Server
   ```
   The client now knows that extension `0x0003` is not supported and must adapt its behavior accordingly.

5. **Example Use Case with Unsupported Extension**:
   A client requesting only extension `0x0002`, but the server doesn't support it:
   ```
   Client --- RequestExtensions [0x0002] ---> Server  
   Client <--- RequestExtensions.Error [unsupported: 0x0002, required: []] ---- Server
   ```
   The client now knows that extension `0x0002` is not supported, but since no extensions are required by the server, the client MAY continue without using any extensions.

6. **Example Use Case with Server Requesting Extensions**:
   A server requiring extension `0x0005`, but the client did not include it in its request:
   ```
   Client --- RequestExtensions [0x0002, 0x0003] ---> Server  
   Client <--- RequestExtensions.Error [unsupported: 0x0003, required: 0x0005] ---- Server
   ```
   The client now knows that the server requires extension `0x0005` and MAY choose to retry with a modified request. If the client does not retry with the required extension, the server MUST disconnect the client.