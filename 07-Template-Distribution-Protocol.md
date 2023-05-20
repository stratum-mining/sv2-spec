# 7. Template Distribution Protocol

The Template Distribution protocol is used to receive updates of the block template to use in mining the next block.
It effectively replaces [BIP 22](https://github.com/bitcoin/bips/blob/master/bip-0022.mediawiki) and [BIP 23](https://github.com/bitcoin/bips/blob/master/bip-0023.mediawiki) (`getblocktemplate`) and provides a much more efficient API which allows Bitcoin Core (or some other full node software) to push template updates at more appropriate times as well as provide a template which may be mined on quickly for the block-after-next.
While not recommended, the template update protocol can be a remote server, and is thus authenticated and signed in the same way as all other protocols (using the same SetupConnection handshake).

Like the Job Negotiation and Job Distribution protocols, all Template Distribution messages have the `channel_msg` bit unset, and there is no concept of channels.
After the initial common handshake, the client MUST immediately send a `SetPoolOutputs` message to indicate the space it requires for coinbase output addition, to which the server MUST immediately reply with the current best block template it has available to the client.
Thereafter, the server SHOULD push new block templates to the client whenever the total fee in the current block template increases materially, and MUST send updated block templates whenever it learns of a new block.

Template Providers MUST attempt to broadcast blocks which are mined using work they provided, and thus MUST track the work which they provided to clients.

## 7.1 `SetupConnection` Flags for Template Distribution Protocol

Flags usable in `SetupConnection.flags` and `SetupConnection.Error::flags`, where bit 0 is the least significant bit of the u32 type:

| Field Name               | Bit | Description                                                                           |
| ------------------------ | --- | ------------------------------------------------------------------------------------- |
| REQUIRE_TX_SHORT_LIST    | 0   | The client require to receive a tx short hash list for each  new template received.   |
|                          |     | The server  MUST send a `TxShortHashList` for each `NewTemplate`.                     |

## 7.2 `SetPoolOutputs` (Client -> Server)


| Field Name                | Data Type          | Description                                                            |
| ------------------------- | ------------------ | ---------------------------------------------------------------------- |
| coinbase_outputs          | B0_64K             | Serialized outputs to be added as the first outputs in the coinbase    |
| coinbase_tx_outputs_count | U32                | The number of transaction outputs included in coinbase_tx_outputs      | 

## 7.3 `GetLastTemplate` (Client -> Server)

When a client send this message the server MUST build and send a `NewTemplate` using the last received pool's
coinbase outputs. If no outputs have been received the server MUST ignore the message.

| Field Name                          | Data Type | Description                                                                                     |
| ----------------------------------- | --------- | ----------------------------------------------------------------------------------------------- |

## 7.4 `NewTemplate` (Server -> Client)

The primary template-providing function. Note that the `coinbase_tx_outputs` bytes will appear as is at the end of the coinbase transaction.

| Field Name                  | Data Type      | Description                                                                                                                                                                                                                                                                        |
| --------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| template_id                 | U64            | Server’s identification of the template. Strictly increasing, the current UNIX time may be used in place of an ID                                                                                                                                                                  |
| future_template             | BOOL           | True if the template is intended for future SetNewPrevHash message sent on the channel. If False, the job relates to the last sent SetNewPrevHash message on the channel and the miner should start to work on the job immediately.                                                |
| version                     | U32            | Valid header version field that reflects the current network consensus. The general purpose bits (as specified in BIP320) can be freely manipulated by the downstream node. The downstream node MUST NOT rely on the upstream node to set the BIP320 bits to any particular value. |
| coinbase_tx_version         | U32            | The coinbase transaction nVersion field                                                                                                                                                                                                                                            |
| coinbase_prefix             | B0_255         | Up to 8 bytes (not including the length byte) which are to be placed at the beginning of the coinbase field in the coinbase transaction                                                                                                                                            |
| coinbase_tx_input_sequence  | U32            | The coinbase transaction input's nSequence field                                                                                                                                                                                                                                   |
| coinbase_tx_value_remaining | U64            | The value, in satoshis, available for spending in coinbase outputs added by the client. Includes both transaction fees and block subsidy.                                                                                                                                          |
| coinbase_tx_outputs_count   | U32            | The number of transaction outputs included in coinbase_tx_outputs                                                                                                                                                                                                                  |
| coinbase_tx_outputs         | B0_64K         | Bitcoin transaction outputs to be included as the last outputs in the coinbase transaction                                                                                                                                                                                         |
| coinbase_tx_locktime        | U32            | The locktime field in the coinbase transaction                                                                                                                                                                                                                                     |
| merkle_path                 | SEQ0_255[U256] | Merkle path hashes ordered from deepest                                                                                                                                                                                                                                            |

## 7.5 `TxShortHashList` (Client -> Server)

If client is a `JobDeclarator`, it need to receive a tx short hash list of the transactions that
are in the block candidate for each `NewTemplate`.

| Field Name                          | Data Type             | Description                                                                                       |
| ----------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------- |
| template_id                         | U64                   | Id of the template from which the tx short hash list have been derived                            |
| tx_short_hash_list                  | SEQ0_64K[SHORT_TX_ID] | Sequence of SHORT_TX_IDs. Inputs to the SipHash functions are transaction hashes from the mempool.|
|                                     |                       | Secret keys k0, k1 are derived from the first two little-endian 64-bit integers from the          |
|                                     |                       | SHA256(tx_short_hash_nonce), respectively (see bip-0152 for more information).                    |
|                                     |                       | Does not include the coinbase transaction (as there is no corresponding full data for it yet).    |
| tx_short_hash_nonce                 | U64                   | A unique nonce used to ensure tx_short_hash collisions are uncorrelated across the network.       |

## 7.6 `SetNewPrevHash` (Server -> Client)

Upon successful validation of a new best block, the server MUST immediately provide a `SetNewPrevHash` message.
If a `NewMiningJob` message has previously been sent with an empty `min_ntime`, which is valid work based on the `prev_hash` contained in this message, the `template_id` field SHOULD be set to the `job_id` present in that `NewTemplate` message indicating the client MUST begin mining on that template as soon as possible.

TODO: Define how many previous works the client has to track (2? 3?), and require that the server reference one of those in `SetNewPrevHash`.

| Field Name       | Data Type | Description                                                                                                                                                                                            |
| ---------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| template_id      | U64       | template_id referenced in a previous NewTemplate message                                                                                                                                               |
| prev_hash        | U256      | Previous block’s hash, as it must appear in the next block's header                                                                                                                                    |
| header_timestamp | U32       | The nTime field in the block header at which the client should start (usually current time). This is NOT the minimum valid nTime value.                                                                |
| nBits            | U32       | Block header field                                                                                                                                                                                     |
| target           | U256      | The maximum double-SHA256 hash value which would represent a valid block. Note that this may be lower than the target implied by nBits in several cases, including weak-block based block propagation. |

## 7.7 `RequestTransactionData` (Client -> Server)

A request sent by the Job Negotiator to the Template Provider which requests the set of transaction data for all transactions (excluding the coinbase transaction) included in a block, as well as any additional data which may be required by the Pool to validate the work.

| Field Name  | Data Type | Description                                            |
| ----------- | --------- | ------------------------------------------------------ |
| template_id | U64       | The template_id corresponding to a NewTemplate message |

## 7.8 `RequestTransactionData.Success` (Server->Client)

A response to `RequestTransactionData` which contains the set of full transaction data and excess data required for validation.
For practical purposes, the excess data is usually the SegWit commitment, however the Job Negotiator MUST NOT parse or interpret the excess data in any way.
Note that the transaction data MUST be treated as opaque blobs and MUST include any SegWit or other data which the Pool may require to verify the transaction.
For practical purposes, the transaction data is likely the witness-encoded transaction today.
However, to ensure backward compatibility, the transaction data MAY be encoded in a way that is different from the consensus serialization of Bitcoin transactions.

Ultimately, having some method of negotiating the specific format of transactions between the Template Provider and the Pool’s Template verification node would be overly burdensome, thus the following requirements are made explicit.
The `RequestTransactionData.Success` sender MUST ensure that the data is provided in a forwards- and backwards-compatible way to ensure the end receiver of the data can interpret it, even in the face of new, consensus-optional data.
This allows significantly more flexibility on both the `RequestTransactionData.Success`-generating and -interpreting sides during upgrades, at the cost of breaking some potential optimizations which would require version negotiation to provide support for previous versions.
For practical purposes, and as a non-normative suggested implementation for Bitcoin Core, this implies that additional consensus-optional data be appended at the end of transaction data.
It will simply be ignored by versions which do not understand it.

To work around the limitation of not being able to negotiate e.g. a transaction compression scheme, the format of the opaque data in `RequestTransactionData.Success` messages MAY be changed in non-compatible ways at the time a fork activates, given sufficient time from code-release to activation (as any sane fork would have to have) and there being some in-Template Negotiation Protocol signaling of support for the new fork (e.g. for soft-forks activated using [BIP 9](https://github.com/bitcoin/bips/blob/master/bip-0009.mediawiki)).

| Field Name       | Data Type        | Description                                                                                                                          |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| template_id      | U64              | The template_id corresponding to a NewTemplate/RequestTransactionData message                                                        |
| excess_data      | B0_64K           | Extra data which the Pool may require to validate the work                                                                           |
| transaction_list | SEQ0_64K[B0_16M] | List of full transactions as requested by ProvideMissingTransactions, in the order they were requested in ProvideMissingTransactions |

## 7.9 `RequestTransactionData.Error` (Server->Client)

| Field Name  | Data Type | Description                                                                   |
| ----------- | --------- | ----------------------------------------------------------------------------- |
| template_id | U64       | The template_id corresponding to a NewTemplate/RequestTransactionData message |
| error_code  | STR0_255  | Reason why no transaction data has been provided                              |

Possible error codes:

- `template-id-not-found`

## 7.10 `SubmitSolution` (Client -> Server)

Upon finding a coinbase transaction/nonce pair which double-SHA256 hashes at or below `SetNewPrevHash::target`, the client MUST immediately send this message, and the server MUST then immediately construct the corresponding full block and attempt to propagate it to the Bitcoin network.

| Field Name       | Data Type | Description                                                                                                                                                                                                                                    |
| ---------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| template_id      | U64       | The template_id field as it appeared in NewTemplate                                                                                                                                                                                            |
| version          | U32       | The version field in the block header. Bits not defined by BIP320 as additional nonce MUST be the same as they appear in the NewMiningJob message, other bits may be set to any value.                                                              |
| header_timestamp | U32       | The nTime field in the block header. This MUST be greater than or equal to the header_timestamp field in the latest SetNewPrevHash message and lower than or equal to that value plus the number of seconds since the receipt of that message. |
| header_nonce     | U32       | The nonce field in the header                                                                                                                                                                                                                  |
| coinbase_tx      | B0_64K    | The full serialized coinbase transaction, meeting all the requirements of the NewMiningJob message, above                                                                                                                                           |

## 7.11 `AllocateTxs` (Client -> Server)

When a pool have a job committed by downstream, it send the tx_short_hash_list of the transactions
that are in the job so that the TP know how to build a block when downstream find a solution.

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                     |                      | negotiation or for identifying custom mining job on mining connection.                            |
| tx_short_hash_list  | SEQ0_64K[SHORT_TX_ID]| Sequence of SHORT_TX_IDs. Inputs to the SipHash functions are transaction hashes from the mempool.|
|                     |                      | Secret keys k0, k1 are derived from the first two little-endian 64-bit integers from the          |
|                     |                      | SHA256(tx_short_hash_nonce), respectively (see bip-0152 for more information).                    |
|                     |                      | Does not include the coinbase transaction (as there is no corresponding full data for it yet).    |
| tx_short_hash_nonce | U64                  | A unique nonce used to ensure tx_short_hash collisions are uncorrelated across the network.       |

## 7.12 `AllocateTxs.Success` (Client -> Server)

That means that the transactions that are in the job with `mining_job_token` has been allocated by
the server and nothing needs to be done by client.

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                     |                      | negotiation or for identifying custom mining job on mining connection.                            |

## 7.13 `IdentifyTransactions` (Client -> Server, Server -> Client)

Sent by the TP to the JDS in response to a `AllocateTxs` message indicating it detected a collision in the `tx_short_hash_list`, or was unable to reconstruct the `tx_hash_list_hash`.
Or sent by the JDC to the TP when the JDS need to identify a transaction.

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                     |                      | negotiation or for identifying custom mining job on mining connection.                            |


## 7.14 `IdentifyTransactions.Success` (Client->Server, Server -> Client)

Sent by the JDS to the TP in response to an `IdentifyTransactions` message to provide the full set of transaction data hashes.
Sent by the TP to the JDC in response to an `IdentifyTransactions` message to provide the full set of transaction data hashes.

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                     |                      | negotiation or for identifying custom mining job on mining connection.                            |
| transactions        | SEQ0_64K[U256]       | The full list of transaction data hashes used to build the mining job in the corresponding        |
|                     |                      | AllocateTxs message                                                                               |

## 7.15 `ProvideMissingTransactions` (Server->Client, Server -> Client)

When the TP do not have tx data for one ore more tx short hash it require, the TP MUST send `ProvideMissingTransactions` 
When the JDC receive `ProvideMissingTransactions` from the JDS it MUST rely it to the TP.

| Field Name               | Data Type            | Description                                                                                       |
| ------------------------ | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token         | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                          |                      | negotiation or for identifying custom mining job on mining connection.                            |
| unknown_tx_position_list | SEQ0_64K[U16]        | A list of unrecognized transactions that need to be supplied by the Job Negotiator in full. They  |
|                          |                      | are specified by their position in the original AllocateTxs message, 0-indexed not including      |
|                          |                      | the coinbase transaction transaction.                                                             |

## 7.16 `ProvideMissingTransactions.Success` (Client->Server, Server -> Client)

This is a message to push transactions that the TP or the JDC did not recognize and requested them to be supplied in `ProvideMissingTransactions`.

| Field Name       | Data Type        | Description                                                                                                                          |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| mining_job_token | B0_255           | Token that makes the client eligible for committing a mining job for approval/transaction negotiation or for identifying custom      |
|                  |                  | mining job on mining connection.                                                                                                     |
| transaction_list | SEQ0_64K[B0_16M] | List of full transactions as requested by ProvideMissingTransactions, in the order they were requested in ProvideMissingTransactions |

## 7.17 `AllocateTxs.Error` (Server -> Client)

When the client provide invalid transaction data the server MUST send `AllocateTxs.Error`

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
|                     |                      | negotiation or for identifying custom mining job on mining connection.                            |
| error_code          | STR0_255             | Reason why no transaction data has been provided                                                  |

## 7.18 `SubmitBlock` (Client -> Server)

When pool receive a solution for a committed job and the transactions in the job have been allocated
with the TP, the pool SHOULD send SubmitBlock.

| Field Name          | Data Type            | Description                                                                                       |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------- |
| mining_job_token    | B0_255               | Token that makes the client eligible for committing a mining job for approval/transaction         |
| version             | U32                  | The version field in the block header.                                                            |
| header_timestamp    | U32                  | The nTime field in the block header.                                                              |
| header_nonce        | U32                  | The nonce field in the header.                                                                    |
| coinbase_tx         | B0_64K               | The full serialized coinbase transaction.                                                         |
