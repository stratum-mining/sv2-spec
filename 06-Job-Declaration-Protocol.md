# 6. Job Declaration Protocol

The Job Declaration Protocol is used to coordinate the creation of custom work, avoiding scenarios where Pools are unilaterally imposing work on miners.

Pools that opt into this protocol are only responsible for accounting shares and distributing rewards.

This is a key feature of Stratum V2 that improves Bitcoin decentralization.

## 6.1 Job Declarator Server

The Job Declarator Server (JDS) is deployed on Pool side, although it could be theoretically outsourced to a third party that is trusted by the Pool.

In order to fully implement the Server side of the Job Declaration Protocol, the JDC also needs to exchange RPCs with a Bitcoin Node. 

It is responsible for:
- Allocating tokens that JDC will use to declare Custom Jobs.
- Acknowledging declaration of Custom Jobs associated with specific allocated tokens.
- Maintaining an internal mempool (via RPCs to a Bitcoin Node).
- Requesting identification for transactions on some declared Custom Job.
- Requesting missing transactions on some declared Custom Job.
- Publishing valid block submissions received from JDC.

## 6.2 Job Declarator Client

The Job Declarator Client (JDC) is deployed on the miner side.

In order to fully implement the Client side of the Job Declaration Protocol, the JDS also needs to operate under the Template Distribution and Mining Protocols.

It is responsible for:
- Receiving Templates from the Template Provider (via Template Distribution Protocol).
- Declaring Custom Jobs to JDS (via Job Declaration Protocol).
- Notifying declared Custom Jobs to Pool (via Mining Protocol).
- Receiving Shares from downstream Mining Devices working on Custom Jobs (via Mining Protocol)..
- Submitting Shares for Custom Jobs to Pool.
- Publishing valid blocks found by downstream Mining Devices (both to TP and JDS).

Additionally, if:
- JDS fails to respond with an `AllocateMiningJobToken.Success` in a reasonable time.
- JDS rejects some Custom Job declaration via `DeclareMiningJob.Error`.
- Pool rejects valid shares under a Custom Job that was previously acknowledged via `SetCustomMiningJob.Success` and/or `DeclareMiningJob.Success`.

JDC is also responsible for switching to a new Pool+JDS (or solo mining as a last resort).

This fallback strategy incentivizes honesty on Pool side, otherwise it will lose hashrate by rejecting Shares for Custom Job that was already acknowledged to be valid.

## 6.3 Job Declaration Protocol Messages

### 6.3.1 `SetupConnection` Flags for Job Declaration Protocol

Flags usable in `SetupConnection.flags` and `SetupConnection.Error::flags`:

| Field Name                | Bit | Description                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------- | --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| REQUIRES_ASYNC_JOB_MINING | 0   | The Job Declarator requires that the mining_job_token in AllocateMiningJobToken.Success can be used immediately on a mining connection in SetCustomMiningJob message, even before DeclareMiningJob and DeclareMiningJob.Success messages have been sent and received. The server MUST only send AllocateMiningJobToken.Success messages with async_mining_allowed set. |

No flags are yet defined for use in `SetupConnection.Success`.

### 6.3.2 `AllocateMiningJobToken` (Client -> Server)

A request to get an identifier for a future-submitted mining job.
Rate limited to a rather slow rate and only available on connections where this has been negotiated. Otherwise, only `mining_job_token(s)` from `AllocateMiningJobToken.Success` are valid.

| Field Name      | Data Type | Description                                                                                                                                                                                                                        |
| --------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| user_identifier | STR0_255  | Unconstrained sequence of bytes. Whatever is needed by the pool to identify/authenticate the client, e.g. "braiinstest". Additional restrictions can be imposed by the pool. It is highly recommended that UTF-8 encoding is used. |
| request_id      | U32       | Unique identifier for pairing the response                                                                                                                                                                                         |

### 6.3.3 `AllocateMiningJobToken.Success` (Server -> Client)

The Server MUST NOT change the value of `coinbase_output_max_additional_size` in `AllocateMiningJobToken.Success` messages unless required for changes to the pool’s configuration.
Notably, if the pool intends to change the space it requires for coinbase transaction outputs regularly, it should simply prefer to use the maximum of all such output sizes as the `coinbase_output_max_additional_size` value.

| Field Name                          | Data Type | Description                                                                                                                                                                                                                                                                                                                                                              |
| ----------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| request_id                          | U32       | Unique identifier for pairing the response                                                                                                                                                                                                                                                                                                                               |
| mining_job_token                    | B0_255    | Token that makes the client eligible for committing a mining job for approval/transaction declaration or for identifying custom mining job on mining connection.                                                                                                                                                                                                         |
| coinbase_output_max_additional_size | U32       | The maximum additional serialized bytes which the pool will add in coinbase transaction outputs. See discussion in the Template Distribution Protocol's CoinbaseOutputDataSize message for more details.                                                                                                                                                                 |
| async_mining_allowed                | BOOL      | If true, the mining_job_token can be used immediately on a mining connection in the SetCustomMiningJob message, even before DeclareMiningJob and DeclareMiningJob.Success messages have been sent and received. If false, Job Declarator MUST use this token for DeclareMiningJob only. <br>This MUST be true when SetupConnection.flags had REQUIRES_ASYNC_JOB_MINING set. |
| coinbase_tx_outputs         | B0_64K         | Bitcoin transaction outputs added by the pool                                                                            |

### 6.3.4 `DeclareMiningJob` (Client -> Server)

A request sent by the Job Declarator that proposes a selected set of transactions to the upstream (pool) node.

| Field Name                  | Data Type             | Description                                                                                                                                                                                                                                                                                                                                                                                                                  |
| --------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id                  | U32                   | Unique identifier for pairing the response                                                                                                                                                                                                                                                                                                                                                                                   |
| mining_job_token            | B0_255                | Previously reserved mining job token received by AllocateMiningJobToken.Success                                                                                                                                                                                                                                                                                                                                              |
| version                     | U32                   | Version header field. To be later modified by BIP320-consistent changes.                                                                                                                                                                                                                                                                                                                                                     |
| coinbase_tx_prefix         | B0_64K                 | The coinbase transaction nVersion field                                                                                                                                                                                                                                                                                                                                                                                       |
| coinbase_tx_suffix         | B0_64K                 | Up to 8 bytes (not including the length byte) which are to be placed at the beginning of the coinbase field in the coinbase transaction                                                                                                                                                                                                                                                                                      |
| tx_short_hash_nonce         | U64                   | A unique nonce used to ensure tx_short_hash collisions are uncorrelated across the network                                                                                                                                                                                                                                                                                                                                   |
| tx_short_hash_list          | SEQ0_64K[SHORT_TX_ID] | Sequence of SHORT_TX_IDs. Inputs to the SipHash functions are transaction hashes from the mempool. Secret keys k0, k1 are derived from the first two little-endian 64-bit integers from the SHA256(tx_short_hash_nonce), respectively (see bip-0152 for more information). Upstream node checks the list against its mempool. Does not include the coinbase transaction (as there is no corresponding full data for it yet). |
| tx_hash_list_hash           | U256                  | Hash of the full sequence of SHA256(transaction_data) contained in the transaction_hash_list                                                                                                                                                                                                                                                                                                                                 |
| excess_data                 | B0_64K                | Extra data which the Pool may require to validate the work (as defined in the Template Distribution Protocol)                                                                                                                                                                                                                                                                                                                |

### 6.3.5 `DeclareMiningJob.Success` (Server -> Client)

| Field Name           | Data Type | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id           | U32       | Identifier of the original request                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| new_mining_job_token | B0_255    | Unique identifier provided by the pool of the job that the Job Declarator has declared with the pool. It MAY be the same token as DeclareMiningJob::mining_job_token if the pool allows to start mining on not yet declared job. If the token is different from the one in the corresponding DeclareMiningJob message (irrespective of if the client is already mining using the original token), the client MUST send a SetCustomMiningJob message on each Mining Protocol client which wishes to mine using the declared job. |

### 6.3.6 `DeclareMiningJob.Error` (Server->Client)

| Field Name    | Data Type | Description                                            |
| ------------- | --------- | ------------------------------------------------------ |
| request_id    | U32       | Identifier of the original request                     |
| error_code    | STR0_255  |                                                        |
| error_details | B0_64K    | Optional data providing further details to given error |

Possible error codes:

- `invalid-mining-job-token`
- `invalid-job-param-value-{}` - `{}` is replaced by a particular field name from `DeclareMiningJob` message

### 6.3.7 `IdentifyTransactions` (Server->Client)

Sent by the Server in response to a `DeclareMiningJob` message indicating it detected a collision in the `tx_short_hash_list`, or was unable to reconstruct the `tx_hash_list_hash`.

| Field Name | Data Type | Description                                                               |
| ---------- | --------- | ------------------------------------------------------------------------- |
| request_id | U32       | Unique identifier for the pairing response to the DeclareMiningJob message |

### 6.3.8 `IdentifyTransactions.Success` (Client->Server)

Sent by the Client in response to an `IdentifyTransactions` message to provide the full set of transaction data hashes.

| Field Name | Data Type      | Description                                                                                                        |
| ---------- | -------------- | ------------------------------------------------------------------------------------------------------------------ |
| request_id | U32            | Unique identifier for the pairing response to the DeclareMiningJob/IdentifyTransactions message                     |
| tx_data_hashes | SEQ0_64K[U256] | The full list of transaction data hashes used to build the mining job in the corresponding DeclareMiningJob message |

### 6.3.9 `ProvideMissingTransactions` (Server->Client)

If `DeclareMiningJob` includes some transactions that JDS's Bitcoin Node has not yet seen, then JDS needs to request that JDC provides those missing ones.

| Field Name               | Data Type     | Description                                                                                                                                                                                                                              |
| ------------------------ | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id               | U32           | Identifier of the original AllocateMiningJobToken request                                                                                                                                                                                |
| unknown_tx_position_list | SEQ0_64K[U16] | A list of unrecognized transactions that need to be supplied by the Job Declarator in full. They are specified by their position in the original DeclareMiningJob message, 0-indexed not including the coinbase transaction transaction. |

### 6.3.10 `ProvideMissingTransactions.Success` (Client->Server)
This is a message to push transactions that the server did not recognize and requested them to be supplied in `ProvideMissingTransactions`.

| Field Name       | Data Type        | Description                                                                                                                          |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| request_id       | U32              | Identifier of the original  AllocateMiningJobToken request                                                                           ""|
| transaction_list | SEQ0_64K[B0_16M] | List of full transactions as requested by ProvideMissingTransactions, in the order they were requested in ProvideMissingTransactions |

### 6.3.11 `SubmitSolution` (Client -> Server)

Sent by JDC as soon as a valid block is found, so that it can be propagated also by JDS.

In the meantime, the block is also transmitted to the network by JDC through the `SubmitSolution` message under in Template Distribution Protocol.

In this way, a valid solution is immediately propagated on both client and server sides, decreasing the chance of the block being orphaned by the network.

| Field Name                              | Data Type | Description                                                                                                                                                                                                                                                                                |
| --------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| extranonce                              | B0_32     | Extranonce bytes which need to be added to coinbase to form a fully valid submission.  (This is the full extranonce)                 |
| prev hash                               | U256      | Hash of the last block                                                                                  |
| nonce                                   | U32       | Nonce leading to the hash being submitted                                                               |
| ntime                                   | U32       | The nTime field in the block header.                                                                    |
| nbits                                   | U32       | Block header field                                                                                      |
