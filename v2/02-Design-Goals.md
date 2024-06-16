# 2. Design Goals
As there are numerous changes from the original Stratum v1 to v2, it may be helpful to briefly review some high-level design goals before getting into more detailed technical specifications:

- Develop a binary protocol with a precise definition.
  Despite its simplicity, v1 was not a precisely defined protocol and ended up with multiple slightly different dialects.
  We don’t want any room for different interpretations of v2.

- Make Stratum v2 logically similar to v1 whenever possible so that it’s easier to understand for people who are already familiar with the protocol.
  V1 is widely used not only in bitcoin mining, but also for mining various altcoins.

- Remove as many issues caused by v1 as possible, based on substantial historical experience with it.
  - Remove explicit mining subscriptions (mining.subscribe) altogether. It was originally part of a more elaborate protocol and is no longer relevant.
  - Make extranonce subscription a native part of the protocol, not an extension.
  - Clean up difficulty controlling, which is really suboptimal v1.
  - Drop JSON.
  - Rework [BIP310](https://github.com/bitcoin/bips/blob/master/bip-0310.mediawiki) from scratch.

- Allow different mining jobs on the same connection. 

- Avoid introducing any additional risks to pool operators and miners since that would make adoption of v2 very improbable.

- Support version rolling natively.
  Bitcoin block header contains a version field whose bits (determined by [BIP320](https://github.com/bitcoin/bips/blob/master/bip-0320.mediawiki)) can be freely used to extend the hashing space for a miner.
  It is already a common tech, we want to include it as a first class citizen in the new protocol.

- Support header-only mining (not touching the coinbase transaction) in as many situations as possible.
  Header-only mining should be easier and faster on mining devices, while also decreasing network traffic.

- Dramatically reduce network traffic as well as client-side and server-side computational intensity, while still being able to send and receive hashing results rapidly for precise hash rate measurement (and therefore more precise mining reward distribution).

- Allow miners to (optionally) choose the transaction set they mine through work declaration on some independent communication channel.
  At the same time, allow miners to choose how they utilize the available bits in the block header `nVersion` field, including both those bits which are used for mining (e.g. version-rolling AsicBoost) by [BIP320](https://github.com/bitcoin/bips/blob/master/bip-0320.mediawiki), and those bits used for [BIP8](https://github.com/bitcoin/bips/blob/master/bip-0008.mediawiki)/[BIP9](https://github.com/bitcoin/bips/tree/master/bip-0009) signaling.
  This mechanism must not interfere with the efficiency or security of the main mining protocol.
  - Use a separate communication channel for transaction selection so that it does not have a performance impact on the main mining/share communication, as well as can be run in three modes - disabled (i.e.pool does not yet support client work selection, to provide an easier transition from Stratum v1), client-push (to maximally utilize the client’s potential block-receive-latency differences from the pool), and client-declared (for pools worried about the potential of clients generating invalid block templates). The key issue to note is that both the client-push and client-declared approaches essentially function as client-push. The primary distinction between them lies in whether the pool validates the job proposed by the miner or not.

- Put complexity on the pool side rather than the miner side whenever possible.
  Keep the protocol part to be implemented in embedded devices as small and easy as possible.
  Mining devices tend to be difficult to update.
  Any mistake in a firmware can be very costly.
  Either on miners side (non-functioning firmware) or pool side (necessity to implement various workarounds and hacks to support misbehaving firmware).

- Allow for translation to and from the original protocol on a proxy level (e.g. different downstream devices) without the necessity to reconnect.

- Reduce the stale ratio as much as possible through efficiency improvements.

- Support/allow for `nTime` rolling in hardware in a safe and controlled way.

- Simple support for vendor-specific extensions without polluting the protocol, or complicating pool implementation.

- Optional telemetry data, allowing for easy monitoring of farms, without sacrificing the privacy of miners who wish to remain private.

- Allow aggregation of connections to upstream nodes with an option to aggregate or not aggregate hash rate for target setting on those connections.

- Ensure protocol design allows for devices to implement their own swarm algorithms.
  Mining devices can dynamically form small groups with an elected master that is responsible for aggregating connections towards upstream endpoint(s), acting as a local proxy.
  Aggregating connections and running multiple channels across a single TCP connection yields a better ratio of actual payload vs TCP/IP header sizes, as the share submission messages are in the range of 20 bytes.
  Still, to avoid overly complicating the protocol, automated negotiation of swarm/proxy detection is left to future extensions or vendor-specific messages.
