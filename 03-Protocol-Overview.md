# Protocol Overview
There are technically four distinct (sub)protocols needed in order to fully use all of the features proposed in this document:

1. **Mining Protocol**  
    The main protocol used for mining and the direct successor of Stratum v1.
    A mining device uses it to communicate with its upstream node, pool, or a proxy.
    A proxy uses it to communicate with a pool (or another proxy).
    This protocol needs to be implemented in all scenarios.
    For cases in which a miner or pool does not support transaction selection, this is the only protocol used.

2. **Job Negotiation Protocol**  
    Used by a miner (a whole mining farm) to negotiate a block template with a pool.
    Results of this negotiation can be re-used for all mining connections to the pool to reduce computational intensity.
    In other words, a single negotiation can be used by an entire mining farm or even multiple farms with hundreds of thousands of devices, making it far more efficient.
    This is separate to allow pools to terminate such connections on separate infrastructure from mining protocol connections (i.e. share submissions).
    Further, such connections have very different concerns from share submissions - work negotiation likely requires, at a minimum, some spot-checking of work validity, as well as potentially substantial rate-limiting (without the inherent rate-limiting of share difficulty).

3. **Template Distribution Protocol**  
   A similarly-framed protocol for getting information about the next block out of Bitcoin Core.
   Designed to replace `getblocktemplate` with something much more efficient and easy to implement for those implementing other parts of Stratum v2.

4. **Job Distribution Protocol**  
   Simple protocol for passing newly-negotiated work to interested nodes - either proxies or miners directly.
   This protocol is left to be specified in a future document, as it is often unnecessary due to the Job Negotiation role being a part of a larger Mining Protocol Proxy.


Meanwhile, there are five possible roles (types of software/hardware) for communicating with these protocols.

1. **Mining Device**  
   The actual device computing the hashes. This can be further divided into header-only mining devices and standard mining devices, though most devices will likely support both modes.

2. **Pool Service**  
   Produces jobs (for those not negotiating jobs via the Job Negotiation Protocol), validates shares, and ensures blocks found by clients are propagated through the network (though clients which have full block templates MUST also propagate blocks into the Bitcoin P2P network).

3. **Mining Proxy (optional)**  
   Sits in between Mining Device(s) and Pool Service, aggregating connections for efficiency.
   May optionally provide additional monitoring, receive work from a Job Negotiator and use custom work with a pool, or provide other services for a farm.

4. **Job Negotiator (optional)**  
   Receives custom block templates from a Template Provider and negotiates use of the template with the pool using the Job Negotiation Protocol.
   Further distributes the jobs to Mining Proxy (or Proxies) using the Job Distribution Protocol. This role will often be a built-in part of a Mining Proxy.

5. **Template Provider**  
   Generates custom block templates to be passed to the Job Negotiator for eventual mining.
   This is usually just a Bitcoin Core full node (or possibly some other node implementation).


The Mining Protocol is used for communication between a Mining Device and Pool Service, Mining Device and Mining Proxy, Mining Proxy and Mining Proxy, or Mining Proxy and Pool Service.

The Job Negotiation Protocol is used for communication between a Job Negotiator and Pool Service.

The Template Distribution Protocol is used for communication between a Job Negotiator and Template Provider.

The Job Distribution Protocol is used for communication between a Job Negotiator and a Mining Proxy.

One type of software/hardware can fulfill more than one role (e.g. a Mining Proxy is often both a Mining Proxy and a Job Negotiator and may occasionally further contain a Template Provider in the form of a full node on the same device).

Each sub-protocol is based on the same technical principles and requires a connection oriented transport layer, such as TCP.
In specific use cases, it may make sense to operate the protocol over a connectionless transport with FEC or local broadcast with retransmission.
However, that is outside of the scope of this document.
The minimum requirement of the transport layer is to guarantee ordered delivery of the protocol messages.
