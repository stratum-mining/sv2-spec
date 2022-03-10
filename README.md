# Stratum V2 Protocol Specification
This repository contains the Stratum V2 protocol specification.

- [0. Abstract](https://github.com/stratum-mining/sv2-spec/blob/main/00-Abstract.md)
- [1. Motivation](https://github.com/stratum-mining/sv2-spec/blob/main/01-Motivation.md)
- [2. Design Goals](https://github.com/stratum-mining/sv2-spec/blob/main/02-Design-Goals.md)
- [3. Protocol Overview](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md)
  - [3.1 Data Types Mapping](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#31-data-types-mapping)
  - [3.2 Framing](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#32-framing)
  - [3.3 Protocol Security](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#33-protocol-security)
    - [3.3.1 Motivation for Authenticated Encryption with Associated Data](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#331-motivation-for-authenticated-encryption-with-associated-data)
    - [3.3.2 Motivation for Using the Noise Protocol Framework](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#332-motivation-for-using-the-noise-protocol-framework)
    - [3.3.3 Authenticated Key Agreement Handshake](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#333-authenticated-key-agreement-handshake)
    - [3.3.4 Signature Noise Message](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#334-signature-noise-message)
    - [3.3.5 Certificate Format](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#335-certificate-format)
    - [3.3.6 URL Scheme and Pool Authority Key](https://github.com/stratum-mining/sv2-spec/blob/main/03-Protocol-Overview.md#336-url-scheme-and-pool-authority-key)

## Authors
Pavel Moravec <pavel@braiins.com>  
Jan Čapek <jan@braiins.com>  
Matt Corallo <bipstratum@bluematt.me>
