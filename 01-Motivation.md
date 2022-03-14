# 1. Motivation
Stratum protocol v1 is JSON-based and lacks cryptographic authentication, making it slower, heavier, and less secure than it can be considering the alternatives available today.
Given the cryptocurrency mining industry’s continued maturation and growth, it’s necessary to address v1’s deficiencies and move to a more efficient solution with a precise definition.

One of the primary motivations of the new protocol is to reduce the amount and respective size of data transfers between miners, proxies, and pool operators to an absolute minimum.
This will enable stratum servers to use the saved bandwidth for higher submission rates, thus yielding a reduced variance in hash rate (and in turn in miner payouts).

To increase efficiency further, we will enable a simplified mode for end mining devices which completely eliminates the need for extranonce and Merkle path handling (i.e. any coinbase modification on downstream machines).
This mode, called header-only mining, makes computations simpler for miners and work validation much lighter on the server side.
Furthermore, header-only mining reduces the cost of future changes to the Bitcoin protocol, as mining firmware and protocols do not need to be upgraded in conjunction with full nodes.

In terms of security, another important improvement to make is hardening the protocol against man-in-the-middle attacks by providing a way for mining devices to verify the integrity of the assigned mining jobs and other commands.

Last but not the least, this protocol strives to allow downstream nodes to choose mining jobs and efficiently communicate them to upstream nodes to reduce power currently held by mining pools (block version selection, transaction selection). This should be possible without harming public pool business models or otherwise leading to more centralization in another area of the mining industry. 
