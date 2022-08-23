# 0. Abstract

We propose a new version of the Stratum Protocol (Stratum Version 2 or Sv2) for cryptocurrency mining pools to improve scaling, security, decentralization, and data transfer efficiency.

Stratum Version 1 was not designed to operate at the scale of current cryptocurrency mining pools. Communications are unencrypted, unoptimized, and resticts block template creators, who determine a new block's transaction set, to pool operators.

Stratum v2 optimizes network communications, offers by-default encryption using the NOISE protocol, and decentralizes block template creation to end mining device operators.

We selected tradeoffs in the protocol's design optimizing for scalability, security, and decentralization. We discuss the design choices in detail in the folllowing section.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC2119.

We keep the name "Stratum" recognizing that this is an upgrade of the widespread protocol version 1: this protocol improves on the design of v1, allows for v1 <-> v2 compatible proxy communication, and maintains the fundamental entity relationships used in Stratum v1.
