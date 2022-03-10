# Protocol Security
Stratum V2 employs a type of encryption scheme called AEAD (authenticated encryption with associated data) to address the security aspects of all communication that occurs between clients and servers.
This provides both confidentiality and integrity for the ciphertexts (i.e. encrypted data) being transferred, as well as providing integrity for associated data which is not encrypted.
Prior to opening any Stratum V2 channels for mining, clients MUST first initiate the cryptographic session state that is used to encrypt all messages sent between themselves and servers.
Thus, the cryptographic session state is independent of V2 messaging conventions. 

At the same time, this specification proposes optional use of a particular handshake protocol based on the **[Noise Protocol framework](https://noiseprotocol.org/noise.html)**.
The client and server establish secure communication using Diffie-Hellman (DH) key agreement, as described in greater detail in the Authenticated Key Agreement Handshake section below.

Using the handshake protocol to establish secured communication is optional on the local network (e.g. local mining devices talking to a local mining proxy).
However, it is mandatory for remote access to the upstream nodes, whether they be pool mining services, job negotiating services or template distributors.
