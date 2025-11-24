# 9. Extensions

## Extension Type Field Usage

When implementing extensions, it's important to understand how the `extension_type` field in the message frame header should be set:

- The `extension_type` field identifies the extension that **introduced and defined the non-TLV fields** of a message.
- For messages defined in the core specification, `extension_type` MUST be `0x0000`.
- For new messages introduced by an extension, `extension_type` MUST be set to that extension's identifier.
- When an extension modifies an existing message using TLV fields, the `extension_type` in the frame header **does not change** - it remains set to the extension that originally defined the message structure (or `0x0000` for core messages).

For a detailed explanation with examples, see [Section 3.4.1 Extension Type Field Usage](./03-Protocol-Overview.md#341-extension-type-field-usage) in the Protocol Overview.

## Extension Registry

| Extension Type | Extension Name         | Description / BIP                                         |
| -------------- | ---------------------- | --------------------------------------------------------- |
| 0x0001         | Extensions Negotiation | Definition [here](./extensions/0x0001-extensions-negotiation.md) |
| 0x0002         | Worker Specific Hashrate Tracking | Definition [here](./extensions/0x0002-worker-specific-hashrate-tracking.md) |
