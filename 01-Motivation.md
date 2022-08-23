# 1. Motivation

Stratum v1 network communication uses a plaintext JSON RPC without cryptographic authentication. V1's JSON design decision allowed for human readability at the cost of security and data efficiency. It is slower, heavier, and less secure than a protocol optimized for computer communication using modern networking techniques.

We find it necessary to address v1's security deficiencies as the Bitcoin mining industry maturates and grows, and to precisely define the design goals of mining entities' communication protocols.

Stratum v2 minimizes the amount, and respective size, of data transfers between miners, proxies, and pool operators. Faster, more efficient communication means higher submission rates and reduced variance in hash rate (in turn, miner payouts).

We create a simplified mining mode, 'header-only mining', for end-mining devices by eliminating extranonce, Merkle path handling, and any other coinbase modification on downstream machines.

Header-only mining allows for further specialization of end-mining machines, moving coinbase modification upstream to a stratum server. It reduces the cost of future changes to the Bitcoin protocol; firmware and protocols for end-mining devices can upgrade independently of upgrades to full nodes.

Stratum v2 introduces by-default encryption and authentication using the NOISE protocol, hardening the protocol against man-in-the-middle attacks.

Finally, Stratum v2 allows downstream miners and mining farms themselves to choose mining jobs, select transactions, build block templates, and efficiently communicate them to upstream nodes. Decentralizing block template creation makes the Bitcoin network more robust, and integrating this change into the Stratum protocol itself allows for decentralization without modifying/harming public pool business models or otherwise leading to more centralization in another area of the mining industry.
