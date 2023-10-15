# 6. Job Declaration Protocol

As outlined above, this protocol runs between the Job Declarator and Pool and can be provided as a trusted 3rd party service for mining farms.

Protocol flow:

![5.a-Job-Declaration-Protocol-Flow](./img/5.a-Job-Declaration-Protocol-Flow.png)  
Figure 5.a Job Declaration Protocol: Flow

## 6.1 Job Declaration Protocol Messages

### 6.1.1 `SetupConnection` Flags for Job Declaration Protocol

Flags usable in `SetupConnection.flags` and `SetupConnection.Error::flags`:

| Field Name                | Bit | Description                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------- | --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| REQUIRES_ASYNC_JOB_MINING | 0   | The Job Declarator requires that the mining_job_token in AllocateMiningJobToken.Success can be used immediately on a mining connection in SetCustomMiningJob message, even before DeclareMiningJob and DeclareMiningJob.Success messages have been sent and received. The server MUST only send AllocateMiningJobToken.Success messages with async_mining_allowed set. |

No flags are yet defined for use in `SetupConnection.Success`.

### 6.1.2 `AllocateMiningJobToken` (Client -> Server)

A request to get an identifier for a future-submitted mining job.
Rate limited to a rather slow rate and only available on connections where this has been negotiated. Otherwise, only `mining_job_token(s)` from `CreateMiningJob.Success` are valid.

| Field Name      | Data Type | Description                                                                                                                                                                                                                        |
| --------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| user_identifier | STR0_255  | Unconstrained sequence of bytes. Whatever is needed by the pool to identify/authenticate the client, e.g. "braiinstest". Additional restrictions can be imposed by the pool. It is highly recommended that UTF-8 encoding is used. |
| request_id      | U32       | Unique identifier for pairing the response                                                                                                                                                                                         |

### 6.1.3 `AllocateMiningJobToken.Success` (Server -> Client)

The Server MUST NOT change the value of `coinbase_output_max_additional_size` in `AllocateMiningJobToken.Success` messages unless required for changes to the pool’s configuration.
Notably, if the pool intends to change the space it requires for coinbase transaction outputs regularly, it should simply prefer to use the maximum of all such output sizes as the `coinbase_output_max_additional_size` value.

| Field Name                          | Data Type | Description                                                                                                                                                                                                                                                                                                                                                              |
| ----------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| request_id                          | U32       | Unique identifier for pairing the response                                                                                                                                                                                                                                                                                                                               |
| mining_job_token                    | B0_255    | Token that makes the client eligible for committing a mining job for approval/transaction declaration or for identifying custom mining job on mining connection.                                                                                                                                                                                                         |
| coinbase_output_max_additional_size | U32       | The maximum additional serialized bytes which the pool will add in coinbase transaction outputs. See discussion in the Template Distribution Protocol's CoinbaseOutputDataSize message for more details.                                                                                                                                                                 |
| async_mining_allowed                | BOOL      | If true, the mining_job_token can be used immediately on a mining connection in the SetCustomMiningJob message, even before DeclareMiningJob and DeclareMiningJob.Success messages have been sent and received. If false, Job Declarator MUST use this token for DeclareMiningJob only. <br>This MUST be true when SetupConnection.flags had REQUIRES_ASYNC_JOB_MINING set. |
| coinbase_tx_outputs         | B0_64K         | Bitcoin transaction outputs added by the pool                                                                            |

### 6.1.4 `DeclareMiningJob` (Client -> Server)

A request sent by the Job Declarator that proposes a selected set of transactions to the upstream (pool) node.

| Field Name                  | Data Type             | Description                                                                                                                                                                                                                                                                                                                                                                                                                  |
| --------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id                  | U32                   | Unique identifier for pairing the response                                                                                                                                                                                                                                                                                                                                                                                   |
| mining_job_token            | B0_255                | Previously reserved mining job token received by AllocateMiningJobToken.Success                                                                                                                                                                                                                                                                                                                                              |
| version                     | U32                   | Version header field. To be later modified by BIP320-consistent changes                                                                                                                                                                                                                                                                                                                                                      |
| coinbase_tx_version         | U32                   | The coinbase transaction nVersion field                                                                                                                                                                                                                                                                                                                                                                                      |
| coinbase_prefix             | B0_255                | Up to 8 bytes (not including the length byte) which are to be placed at the beginning of the coinbase field in the coinbase transaction                                                                                                                                                                                                                                                                                      |
| coinbase_tx_input_nSequence | U32                   | The coinbase transaction input's nSequence field                                                                                                                                                                                                                                                                                                                                                                             |
| coinbase_tx_value_remaining | U64                   | The value, in satoshis, available for spending in coinbase outputs added by the client. Includes both transaction fees and block subsidy.                                                                                                                                                                                                                                                                                    |
| coinbase_tx_outputs         | B0_64K                | Bitcoin transaction outputs to be included as the last outputs in the coinbase transaction                                                                                                                                                                                                                                                                                                                                   |
| coinbase_tx_locktime        | U32                   | The locktime field in the coinbase transaction                                                                                                                                                                                                                                                                                                                                                                               |
| min_extranonce_size         | U16                   | Extranonce size requested to be always available for the mining channel when this job is used on a mining connection                                                                                                                                                                                                                                                                                                         |
| tx_short_hash_nonce         | U64                   | A unique nonce used to ensure tx_short_hash collisions are uncorrelated across the network                                                                                                                                                                                                                                                                                                                                   |
| tx_short_hash_list          | SEQ0_64K[SHORT_TX_ID] | Sequence of SHORT_TX_IDs. Inputs to the SipHash functions are transaction hashes from the mempool. Secret keys k0, k1 are derived from the first two little-endian 64-bit integers from the SHA256(tx_short_hash_nonce), respectively (see bip-0152 for more information). Upstream node checks the list against its mempool. Does not include the coinbase transaction (as there is no corresponding full data for it yet). |
| tx_hash_list_hash           | U256                  | Hash of the full sequence of SHA256(transaction_data) contained in the transaction_hash_list                                                                                                                                                                                                                                                                                                                                 |
| excess_data                 | B0_64K                | Extra data which the Pool may require to validate the work (as defined in the Template Distribution Protocol)                                                                                                                                                                                                                                                                                                                |

### 6.1.5 `DeclareMiningJob.Success` (Server -> Client)

| Field Name           | Data Type | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id           | U32       | Identifier of the original request                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| new_mining_job_token | B0_255    | Unique identifier provided by the pool of the job that the Job Declarator has declared with the pool. It MAY be the same token as DeclareMiningJob::mining_job_token if the pool allows to start mining on not yet declared job. If the token is different from the one in the corresponding DeclareMiningJob message (irrespective of if the client is already mining using the original token), the client MUST send a SetCustomMiningJob message on each Mining Protocol client which wishes to mine using the declared job. |

### 6.1.6 `DeclareMiningJob.Error` (Server->Client)

| Field Name    | Data Type | Description                                            |
| ------------- | --------- | ------------------------------------------------------ |
| request_id    | U32       | Identifier of the original request                     |
| error_code    | STR0_255  |                                                        |
| error_details | B0_64K    | Optional data providing further details to given error |

Possible error codes:

- `invalid-mining-job-token`
- `invalid-job-param-value-{}` - `{}` is replaced by a particular field name from `DeclareMiningJob` message

### 6.1.7 `IdentifyTransactions` (Server->Client)

Sent by the Server in response to a `DeclareMiningJob` message indicating it detected a collision in the `tx_short_hash_list`, or was unable to reconstruct the `tx_hash_list_hash`.

| Field Name | Data Type | Description                                                               |
| ---------- | --------- | ------------------------------------------------------------------------- |
| request_id | U32       | Unique identifier for the pairing response to the DeclareMiningJob message |

### 6.1.8 `IdentifyTransactions.Success` (Client->Server)

Sent by the Client in response to an `IdentifyTransactions` message to provide the full set of transaction data hashes.

| Field Name | Data Type      | Description                                                                                                        |
| ---------- | -------------- | ------------------------------------------------------------------------------------------------------------------ |
| request_id | U32            | Unique identifier for the pairing response to the DeclareMiningJob/IdentifyTransactions message                     |
| tx_data_hashes | SEQ0_64K[U256] | The full list of transaction data hashes used to build the mining job in the corresponding DeclareMiningJob message |

### 6.1.9 `ProvideMissingTransactions` (Server->Client)

| Field Name               | Data Type     | Description                                                                                                                                                                                                                             |
| ------------------------ | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_id               | U32           | Identifier of the original CreateMiningJob request                                                                                                                                                                                      |
| unknown_tx_position_list | SEQ0_64K[U16] | A list of unrecognized transactions that need to be supplied by the Job Declarator in full. They are specified by their position in the original DeclareMiningJob message, 0-indexed not including the coinbase transaction transaction. |

### 6.1.10 `ProvideMissingTransactions.Success` (Client->Server)

This is a message to push transactions that the server did not recognize and requested them to be supplied in `ProvideMissingTransactions`.

| Field Name       | Data Type        | Description                                                                                                                          |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| request_id       | U32              | Identifier of the original CreateMiningJob request                                                                                   |
| transaction_list | SEQ0_64K[B0_16M] | List of full transactions as requested by ProvideMissingTransactions, in the order they were requested in ProvideMissingTransactions |

### 6.1.11 `SubmitSolution` (Client -> Server)


| Field Name                              | Data Type | Description                                                                                                                                                                                                                                                                                |
| --------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `<SubmitSharesStandard message fields>` | See chapter 5.3.11
| extranonce                              | B0_32     | Extranonce bytes which need to be added to coinbase to form a fully valid submission (full coinbase = coinbase_tx_prefix + extranonce_prefix + extranonce + coinbase_tx_suffix). The size of the provided extranonce MUST be equal to the negotiated extranonce size from channel opening. |
| prev hash                               | B0_32     | Hash of the last block                                                                                  |

### 6.1.12 `SubmitSolution.Success` (Server -> Client)

Response to `SubmitSharesExtended`, accepting results from the miner.
In JD case this is a Success response for a share that is under Bitcoin target, so it's for a valid block so there is no need to group or count valid shares in this case becasue it will be always be one.

| Field Name                 | Data Type | Description                                         |
| -------------------------- | --------- | --------------------------------------------------- |

The server does not have to double check that the sequence numbers sent by a client are actually increasing.
It can simply use the last one received when sending a response.
It is the client’s responsibility to keep the sequence numbers correct/useful.
