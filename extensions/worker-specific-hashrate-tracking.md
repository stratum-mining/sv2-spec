# Stratum V2 Extension: Worker-Specific Hashrate Tracking

## 0. Abstract

This document proposes a Stratum V2 extension to enable mining pools to track individual workers (`user_identity`) within extended channels. By extending the `SubmitSharesExtended` message to include a mandatory `user_identity` field (up to 32 bytes), pools can track worker-specific hashrate while preserving the existing channel structure.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Overview

This extension modifies the existing `SubmitSharesExtended` message by adding a mandatory `user_identity` field. Clients must populate this field to allow the pool to track individual worker performance.

### 1.1 Activate Extension

To enable the extension, the client MUST send a `RequestExtensions` message immediately after the `SetupConnection` message. This message includes a list of requested extensions by their `U32` identifiers. If the pool supports the requested extensions, it responds with a `RequestExtensions.Success` message containing the list of supported `U32` extension identifiers. If the pool does not support any of the requested extensions, it responds with a `RequestExtensions.Error` message.

#### Message Exchange Example

1. **Connection Setup**:
    ```
    Client --- SetupConnection (connection details) ---> Server
    Client <--- SetupConnection.Success (connection accepted) ---- Server
    ```

2. **Extension Request**:
    ```
    Client --- RequestExtensions [0x0002] ---> Server
    ```

3. **Server Response**:
   - If successful:
     ```
     Client <--- RequestExtensions.Success [0x0002] ---- Server
     ```
   - If an error occurs:
     ```
     Client <--- RequestExtensions.Error [0x0002] ---- Server
     ```

The client MUST include the `user_identity` field in the `SubmitSharesExtended` message only if the extension has been successfully activated.

### 1.2 Behavior Based on Negotiation

- **If the extension is negotiated**:
    - The `user_identity` field **MUST** be populated with a valid identifier for the worker.
- **If the extension is not negotiated**:
    - The `user_identity` field **MUST** either be omitted or have a length of zero.

---

### 2 Bandwidth Consideration

Including the `user_identity` field in each share submission increases message size, depending on the length of the identifier (up to 32 bytes).

For example:
- **Without `user_identity`**: Share message size ~70 bytes.
- **With maximum `user_identity` (32 bytes)**: Share message size ~102 bytes.

In a scenario with 10 shares per minute per channel:
- **Maximum increase**: 32 bytes × 10 = 320 bytes/min, or 19.2 KB/hour.
- **Average increase (20 bytes)**: 200 bytes/min, or 12 KB/hour.

---

## 3. Implementation Notes

### 3.1 Job Difficulty Management

As the number of workers in a single extended channel increases, the time required to receive shares from all individual machines also increases. If a server wants to offer this monitoring, it should manage job difficulty accordingly to ensure timely processing of shares.

### 3.2 Privacy Considerations

Mining farms should be aware that sharing per-worker data with pools could reveal operational insights. This could potentially compromise the privacy of the mining farm's operations.

---