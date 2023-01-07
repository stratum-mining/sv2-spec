# 7. Template Distribution Protocol

The Template Distribution protocol is used to receive updates of the block template to use in mining the next block.
It effectively replaces [BIP 22](https://github.com/bitcoin/bips/blob/master/bip-0022.mediawiki) and [BIP 23](https://github.com/bitcoin/bips/blob/master/bip-0023.mediawiki) (`getblocktemplate`) and provides a much more efficient API which allows Bitcoin Core (or some other full node software) to push template updates at more appropriate times as well as provide a template which may be mined on quickly for the block-after-next.
While not recommended, the template update protocol can be a remote server, and is thus authenticated and signed in the same way as all other protocols (using the same SetupConnection handshake).

Like the Job Negotiation and Job Distribution protocols, all Template Distribution messages have the `channel_msg` bit unset, and there is no concept of channels.
After the initial common handshake, the client MUST immediately send a `CoinbaseOutputDataSize` message to indicate the space it requires for coinbase output addition, to which the server MUST immediately reply with the current best block template it has available to the client.
Thereafter, the server SHOULD push new block templates to the client whenever the total fee in the current block template increases materially, and MUST send updated block templates whenever it learns of a new block.

Template Providers MUST attempt to broadcast blocks which are mined using work they provided, and thus MUST track the work which they provided to clients.

## 7.1 `CoinbaseOutputDataSize` (Client -> Server)

Ultimately, the pool is responsible for adding coinbase transaction outputs for payouts and other uses, and thus the Template Provider will need to consider this additional block size when selecting transactions for inclusion in a block (to not create an invalid, oversized block).
Thus, this message is used to indicate that some additional space in the block/coinbase transaction be reserved for the pool’s use (while always assuming the pool will use the entirety of available coinbase space).

The Job Negotiator MUST discover the maximum serialized size of the additional outputs which will be added by the pool(s) it intends to use this work.
It then MUST communicate the maximum such size to the Template Provider via this message.
The Template Provider MUST NOT provide `NewWork` messages which would represent consensus-invalid blocks once this additional size — along with a maximally-sized (100 byte) coinbase field — is added.
Further, the Template Provider MUST consider the maximum additional bytes required in the output count variable-length integer in the coinbase transaction when complying with the size limits.

| Field Name                          | Data Type | Description                                                                                     |
| ----------------------------------- | --------- | ----------------------------------------------------------------------------------------------- |
| coinbase_output_max_additional_size | U32       | The maximum additional serialized bytes which the pool will add in coinbase transaction outputs |

## 7.2 `NewTemplate` (Server -> Client)

The primary template-providing function. Note that the `coinbase_tx_outputs` bytes will appear as is at the end of the coinbase transaction.

| Field Name                  | Data Type      | Description                                                                                                                                                                                                                                                                        |
| --------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --- | --- | ------------------------ |
| template_id                 | U64            | Server’s identification of the template. Strictly increasing, the current UNIX time may be used in place of an ID                                                                                                                                                                  |
| future_template             | BOOL           | True if the template is intended for future SetNewPrevHash message sent on the channel. If False, the job relates to the last sent SetNewPrevHash message on the channel and the miner should start to work on the job immediately.                                                |
| version                     | U32            | Valid header version field that reflects the current network consensus. The general purpose bits (as specified in BIP320) can be freely manipulated by the downstream node. The downstream node MUST NOT rely on the upstream node to set the BIP320 bits to any particular value. |
| coinbase_tx_version         | U32            | The coinbase transaction nVersion field                                                                                                                                                                                                                                            |
| coinbase_prefix             | B0_255         | Up to 8 bytes (not including the length byte) which are to be placed at the beginning of the coinbase field in the coinbase transaction.                                                                                                                                           |
| coinbase_tx_input_sequence  | U32            | The coinbase transaction input's nSequence field                                                                                                                                                                                                                                   |
| coinbase_tx_value_remaining | U64            | The value, in satoshis, available for spending in coinbase outputs added by the client. Includes both transaction fees and block subsidy.                                                                                                                                          |
| coinbase_tx_outputs_count   | U32            | The number of transaction outputs included in coinbase_tx_outputs                                                                                                                                                                                                                  |
| coinbase_tx_outputs         | B0_64K         | Bitcoin transaction outputs to be included as the last outputs in                                                                                                                                                                                                                  |     |     | the coinbase transaction |
| coinbase_tx_locktime        | U32            | The locktime field in the coinbase transaction                                                                                                                                                                                                                                     |
| merkle_path                 | SEQ0_255[U256] | Merkle path hashes ordered from deepest                                                                                                                                                                                                                                            |

## 7.3 `SetNewPrevHash` (Server -> Client)

Upon successful validation of a new best block, the server MUST immediately provide a `SetNewPrevHash` message.
If a `NewWork` message has previously been sent with the `future_job` flag set, which is valid work based on the `prev_hash` contained in this message, the `template_id` field SHOULD be set to the `job_id` present in that `NewTemplate` message indicating the client MUST begin mining on that template as soon as possible.

TODO: Define how many previous works the client has to track (2? 3?), and require that the server reference one of those in `SetNewPrevHash`.

| Field Name       | Data Type | Description                                                                                                                                                                                            |
| ---------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| template_id      | U64       | template_id referenced in a previous NewTemplate message                                                                                                                                               |
| prev_hash        | U256      | Previous block’s hash, as it must appear in the next block's header                                                                                                                                    |
| header_timestamp | U32       | The nTime field in the block header at which the client should start (usually current time). This is NOT the minimum valid nTime value.                                                                |
| nBits            | U32       | Block header field                                                                                                                                                                                     |
| target           | U256      | The maximum double-SHA256 hash value which would represent a valid block. Note that this may be lower than the target implied by nBits in several cases, including weak-block based block propagation. |

## 7.4 `RequestTransactionData` (Client -> Server)

A request sent by the Job Negotiator to the Template Provider which requests the set of transaction data for all transactions (excluding the coinbase transaction) included in a block, as well as any additional data which may be required by the Pool to validate the work.

| Field Name  | Data Type | Description                                            |
| ----------- | --------- | ------------------------------------------------------ |
| template_id | U64       | The template_id corresponding to a NewTemplate message |

## 7.5 `RequestTransactionData.Success` (Server->Client)

A response to `RequestTransactionData` which contains the set of full transaction data and excess data required for validation. For practical purposes, the excess data is usually the SegWit commitment, however the Job Negotiator MUST NOT parse or interpret the excess data in any way. Note that the transaction data MUST be treated as opaque blobs and MUST include any SegWit or other data which the Pool may require to verify the transaction. For practical purposes, the transaction data is likely the witness-encoded transaction today. However, to ensure backward compatibility, the transaction data MAY be encoded in a way that is different from the consensus serialization of Bitcoin transactions.

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

## 7.6 `RequestTransactionData.Error` (Server->Client)

| Field Name  | Data Type | Description                                                                   |
| ----------- | --------- | ----------------------------------------------------------------------------- |
| template_id | U64       | The template_id corresponding to a NewTemplate/RequestTransactionData message |
| error_code  | STR0_255  | Reason why no transaction data has been provided                              |

Possible error codes:

- `template-id-not-found`

## 7.7 `SubmitSolution` (Client -> Server)

Upon finding a coinbase transaction/nonce pair which double-SHA256 hashes at or below `SetNewPrevHash::target`, the client MUST immediately send this message, and the server MUST then immediately construct the corresponding full block and attempt to propagate it to the Bitcoin network.

| Field Name       | Data Type | Description                                                                                                                                                                                                                                    |
| ---------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| template_id      | U64       | The template_id field as it appeared in NewTemplate                                                                                                                                                                                            |
| version          | U32       | The version field in the block header. Bits not defined by BIP320 as additional nonce MUST be the same as they appear in the NewWork message, other bits may be set to any value.                                                              |
| header_timestamp | U32       | The nTime field in the block header. This MUST be greater than or equal to the header_timestamp field in the latest SetNewPrevHash message and lower than or equal to that value plus the number of seconds since the receipt of that message. |
| header_nonce     | U32       | The nonce field in the header                                                                                                                                                                                                                  |
| coinbase_tx      | B0_64K    | The full serialized coinbase transaction, meeting all the requirements of the NewWork message above                                                                                                                                            |
