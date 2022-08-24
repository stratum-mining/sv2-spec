# 2. Design Goals

We briefly summarize our high-level design goals before diving into detailed technical specifications of v1 -> v2 changes:

- **Develop a precisely defined binary protocol.**
  v1's failure to precisely define its specifications led to multiple semicompatible implementations with varying dialects.
  Stratum v2 precisely defines its protocol parameters to ensure spec cross-compatibility.

- **Make Stratum v2 logically similar to v1.**
  v2 is an update to v1, not a separate protocol. It should improve on the logic and framework of v1, allowing for incremental and modular improvements for miners and mining pools currently using stratum v1. Critically, v1 implementations must be able to effectively communicate with v2 implementations with minimal tradeoffs.

- **Eliminate known, established, and identified issues in v1.**

  - Remove explicit mining subscriptions (mining.subscribe).
  - Make extranonce subscription a native part of the protocol, not an extension.
  - Optimize difficulty controlling.
  - Drop JSON.
  - Rework [BIP310](https://github.com/bitcoin/bips/blob/master/bip-0310.mediawiki) from scratch.

- Allow different mining jobs on the same connection (Multiplexing).

- **Avoid introducing additional risks to pool operators and miners since**.

- Support version rolling natively. Bitcoin block headers contain a version field whose bits (determined by [BIP320](https://github.com/bitcoin/bips/blob/master/bip-0320.mediawiki) can be freely used to extend the hashing space for a miner.

- **Support header-only mining (not touching the coinbase transaction) wherever possible.**
  Header-only mining is easier/faster on mining devices and reduces network traffic.

- Dramatically reduce network traffic and computational intensity for clients and servers, without sacrificing precise hash rate measurement for mining reward distribution.

- **Allow miners to (optionally) choose the transaction set they mine through work negotiation on some independent communication channel.**
  Without sacrificing efficiency and security of the main mining protocol, allow miners to choose block header `nVersion` field bits, including both [BIP320](https://github.com/bitcoin/bips/blob/master/bip-0320.mediawiki) mining bits (e.g. version-rolling AsicBoost) , and [BIP8](https://github.com/bitcoin/bips/blob/master/bip-0008.mediawiki)/[BIP9](https://github.com/bitcoin/bips/tree/master/bip-0009) signaling bits.

  - Use a separate communication channel for transaction selection. This avoids performance impact on the main mining/share communication and runs in 3 modes:
    - Disabled (eases transition from Stratum v1 if pool doesn't support client work selection yet)
    - Client-Push (maximizes client’s potential block-receive-latency differences from the pool)
    - Client-Negotiated (if pool assesses client might generate invalid block templates)

- **Push complexity upstream to the pool vs downstream to end-mining devices.**

  - Protocol implementation for embedded devices should be small and easy. Mining devices are difficult to update.
    Firmware mistakes, both miner-side and pool-side, are costly and complex.

- Allow for proxy translation to and from the original protocol without forcing a reconnect.

- Minimize the stale ratio through efficiency improvements.

- Support/allow for safe and controlled `nTime` rolling in hardware.

- Simple support for vendor-specific extensions without polluting the protocol or complicating pool implementation.

- Optional telemetry data for easy monitoring of farms, without sacrificing the privacy of miners who wish to remain private.

- Allow connection aggregation to upstream nodes, optionally aggregating hash rate for target setting on those connections.

- **Allow devices to implement custom swarm algorithms.**
  - Mining devices dynamically form small groups with an elected master, acting as a local proxy responsible for aggregating connections towards upstream endpoint(s).
  - Connection aggregation and multiplexing yields a superior payload/TCPIP header size ratio, reducing share submission message sizes to ~20 bytes.
  - Automated swarm/proxy detection negotiation is left to future extensions or vendor-specific messages.
