# Stratum V2 Extension: Worker-Specific Hashrate Tracking

## 0. Abstract

This document proposes a Stratum V2 extension to enable mining pools to track individual workers (`user_identity`) within extended channels. By extending the `SubmitSharesExtended` message via `Type-Length-Value (TLV)` encoding, pools can track worker-specific hashrate while preserving the existing channel structure.

Terms like "MUST," "MUST NOT," "REQUIRED," etc., follow RFC2119 standards.

---

## 1. Extension Overview

This extension modifies the existing `SubmitSharesExtended` message by introducing a **new TLV field** that contains the `user_identity` (worker name). The extension follows the [Stratum V2 TLV encoding model](../03-Protocol-Overview.md#341-stratum-v2-tlv-encoding-model), where each extension is assigned a `Type (U16)` identifier negotiated between the client and server.

### 1.1 TLV Format for `user_identity`
When this extension is enabled, the client MUST append the following TLV field to `SubmitSharesExtended`:

| Field            | Size      | Description                                                                                                                                                                            |
|------------------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Type (U16 \| U8) | 3 bytes   | Unique identifier for the TLV field, structured as: <br> - **Extension Type (U16)**: `0x0002` (Worker-Specific Hashrate Tracking) <br> - **Field Type (U8)**: `0x01` (`user_identity`) |
| Length (U16)     | 2 bytes   | Length of the value (max **32 bytes**)                                                                                                                                                 |
| Value            | `N` bytes | UTF-8 encoded `user_identity` (worker name)                                                                                                                                            |

If `user_identity` is shorter than **32 bytes**, it MUST NOT be padded. The `Length` field MUST indicate the actual byte size.

---

### **Example TLV Encoding**

```
[TYPE: 0x0002|0x01] [LENGTH: 0x000A] [VALUE: "Worker_001"]
```
(Where `"Worker_001"` is 10 bytes long)

**Breaking it down:**
- `0x0002|0x01` → **Type (U16 | U8)**
    - `0x0002` (**U16 - Extension Type**) → Worker-Specific Hashrate Tracking
    - `0x01` (**U8 - Field Type**) → `user_identity`
- `0x000A` → **Length** (10 bytes)
- `"Worker_001"` → **Value** (UTF-8 encoded string)

### 1.2 Extension Activation (Negotiation Process)

To enable this extension, the initiator MUST send a `RequestExtensions` message immediately after the `SetupConnection` message, requesting extension `0x0002`. If the receiver supports it, it responds with a `RequestExtensions.Success` message.

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

Once negotiated, the client MUST append the TLV containing `user_identity` to every `SubmitSharesExtended` message.

### 1.3 Behavior Based on Negotiation

- **If the extension is negotiated**:
    - The `user_identity` field **MUST** be included in `SubmitSharesExtended` as a TLV with Type `0x0002`.
- **If the extension is not negotiated**:
    - The `user_identity` field **MUST** not be included.
    - The server **MUST** ignore any unexpected TLV fields.

Since all extensions are negotiated before use, **the order of TLV fields is not relevant**. The receiver **MUST** scan for TLV fields corresponding to known negotiated extensions.

---

### 2. Extended `SubmitSharesExtended` Message Format
After negotiation, the client appends TLV fields at the end of `SubmitSharesExtended`.
Example with the `user_identity` extension enabled:
```
[SubmitSharesExtended Base Fields] + [0x0002|0x01] [LENGTH] ["Worker_001"]
```
Example Message in Bytes:
```
<BASE PAYLOAD> + 00 02 01 00 0A 57 6F 72 6B 65 72 5F 30 30 31
```
Where:

- `00 02 01 ` → TLV Type (U16 | U8) (`extension_type = 0x0002`, `field_type = 0x01`)
- `00 0A` → Length (10 bytes)
- `57 6F 72 6B 65 72 5F 30 30 31` → "Worker_001" (UTF-8 encoded)

---

### 3. Bandwidth Consideration

Including the `user_identity` field in each share submission increases message size, depending on the length of the identifier (up to 32 bytes).

For example:
- **Without `user_identity`**: Share message size ~70 bytes.
- **With maximum `user_identity` (32 bytes)**: Share message size ~102 bytes.

In a scenario with 10 shares per minute per channel:
- **Maximum increase**: 32 bytes × 10 = 320 bytes/min, or 19.2 KB/hour.
- **Average increase (20 bytes)**: 200 bytes/min, or 12 KB/hour.

---

## 4. Implementation Notes

### 4.1 Job Difficulty Management

As the number of workers in a single extended channel increases, the time required to receive shares from all individual machines also increases. If a server wants to offer this monitoring, it should manage job difficulty accordingly to ensure timely processing of shares.

### 4.2 Privacy Considerations

Mining farms should be aware that sharing per-worker data with pools could reveal operational insights. This could potentially compromise the privacy of the mining farm's operations.

---