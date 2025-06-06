# Stratum V2 Protocol Specification
This repository contains the Stratum V2 protocol specification.

- [0. Abstract](./00-Abstract.md)
- [1. Motivation](./01-Motivation.md)
- [2. Design Goals](./02-Design-Goals.md)
- [3. Protocol Overview](./03-Protocol-Overview.md)
  - [3.1 Data Types Mapping](./03-Protocol-Overview.md#31-data-types-mapping)
  - [3.2 Framing](./03-Protocol-Overview.md#32-framing)
  - [3.3 Reconnecting Downstream Nodes](./03-Protocol-Overview.md#33-reconnecting-downstream-nodes)
  - [3.4 Protocol Extensions](./03-Protocol-Overview.md#34-protocol-extensions)
  - [3.5 Error Codes](./03-Protocol-Overview.md#35-error-codes)
  - [3.6 Common Protocol Messages](./03-Protocol-Overview.md#36-common-protocol-messages)
    - [3.6.1 SetupConnection (Client -> Server)](./03-Protocol-Overview.md#361-setupconnection-client---server)
    - [3.6.2 SetupConnection.Success (Server -> Client)](./03-Protocol-Overview.md#362-setupconnectionsuccess-server---client)
    - [3.6.3 SetupConnection.Error (Server -> Client)](./03-Protocol-Overview.md#363-setupconnectionerror-server---client)
    - [3.6.4 ChannelEndpointChanged (Server -> Client)](./03-Protocol-Overview.md#364-channelendpointchanged-server---client)
- [4. Protocol Security](./04-Protocol-Security.md)
  - [4.1 Motivation for Authenticated Encryption with Associated Data](./04-Protocol-Security.md#41-motivation-for-authenticated-encryption-with-associated-data)
  - [4.2 Motivation for Using the Noise Protocol Framework](./04-Protocol-Security.md#42-motivation-for-using-the-noise-protocol-framework)
  - [4.3 Choice of cryptographic primitives](./04-Protocol-Security.md#43-choice-of-cryptographic-primitives)
    - [4.3.1 Elliptic Curve](./04-Protocol-Security.md#431-elliptic-curve)
      - [4.3.1.1 EC point encoding remarks](./04-Protocol-Security.md#4311-ec-point-encoding-remarks)
    - [4.3.2 Hash function](./04-Protocol-Security.md#432-hash-function)
    - [4.3.3 Cipher function for authenticated encryption](./04-Protocol-Security.md#433-cipher-function-for-authenticated-encryption)
  - [4.4 Cryptographic operations](./04-Protocol-Security.md#44-cryptographic-operations)
    - [4.4.1 CipherState object](./04-Protocol-Security.md#441-cipherstate-object)
    - [4.4.2 Handshake Operation](./04-Protocol-Security.md#442-handshake-operation)
  - [4.5 Authenticated Key Agreement Handshake](./04-Protocol-Security.md#45-authenticated-key-agreement-handshake)
    - [4.5.1 Handshake Act 1: Noise protocol proposal](./04-Protocol-Security.md#451-handshake-act-1-noise-protocol-proposal)
    - [4.5.2 Handshake Act 2: Noise protocol choice](./04-Protocol-Security.md#452-handshake-act-2-noise-protocol-choice)
    - [4.5.3 Handshake Act 3: NX-handshake part 1 `-> e`](./04-Protocol-Security.md#453-handshake-act-3-nx-handshake-part-1---e)
    - [4.5.4 Handshake Act 4: NX-handshake part 2 `<- e, ee, s, es, SIGNATURE_NOISE_MESSAGE`](./04-Protocol-Security.md#454-handshake-act-4-nx-handshake-part-2---e-ee-s-es-signature_noise_message)
    - [4.5.5 Server authentication](./04-Protocol-Security.md#455-server-authentication)
      - [4.5.5.1 Signature structure](./04-Protocol-Security.md#4551-signature-structure)
    - [4.5.6 Transport message encryption and format](./04-Protocol-Security.md#456-transport-message-encryption-and-format)
  - [4.6 URL Scheme and Pool Authority Key](./04-Protocol-Security.md#46-url-scheme-and-pool-authority-key)
  - [4.7 References](./04-Protocol-Security.md#47-references)
- [5. Mining Protocol](./05-Mining-Protocol.md)
  - [5.1 Jobs](./05-Mining-Protocol.md#51-jobs)
    - [5.1.1 Standard Jobs](./05-Mining-Protocol.md#511-standard-jobs)
    - [5.1.2 Extended Jobs](./05-Mining-Protocol.md#512-extended-jobs)
      - [5.1.2.1 Extended Extranonce](./05-Mining-Protocol.md#5121-extended-extranonce)
    - [5.1.3 Future Jobs](./05-Mining-Protocol.md#513-future-jobs)
    - [5.1.4 Custom Jobs](./05-Mining-Protocol.md#514-custom-jobs)
  - [5.2 Channels](./05-Mining-Protocol.md#52-channels)
    - [5.2.1 Standard Channels](./05-Mining-Protocol.md#521-standard-channels)
    - [5.2.2 Extended Channels](./05-Mining-Protocol.md#522-extended-channels)
    - [5.2.3 Group Channels](./05-Mining-Protocol.md#523-group-channels)
  - [5.3 Mining Protocol Messages](./05-Mining-Protocol.md#53-mining-protocol-messages)
    - [5.3.1 SetupConnection Flags for Mining Protocol](./05-Mining-Protocol.md#531-setupconnection-flags-for-mining-protocol)
    - [5.3.2 OpenStandardMiningChannel (Client -> Server)](./05-Mining-Protocol.md#532-openstandardminingchannel-client---server)
    - [5.3.3 OpenStandardMiningChannel.Success (Server -> Client)](./05-Mining-Protocol.md#533-openstandardminingchannelsuccess-server---client)
    - [5.3.4 OpenExtendedMiningChannel (Client -> Server)](./05-Mining-Protocol.md#534-openextendedminingchannel-client---server)
    - [5.3.5 OpenExtendedMiningChannel.Success (Server -> Client)](./05-Mining-Protocol.md#535-openextendedminingchannelsuccess-server---client)
    - [5.3.6 OpenMiningChannel.Error (Server -> Client)](./05-Mining-Protocol.md#536-openminingchannelerror-server---client)
    - [5.3.7 UpdateChannel (Client -> Server)](./05-Mining-Protocol.md#537-updatechannel-client---server)
    - [5.3.8 UpdateChannel.Error (Server -> Client)](./05-Mining-Protocol.md#538-updatechannelerror-server---client)
    - [5.3.9 CloseChannel (Client -> Server, Server -> Client)](./05-Mining-Protocol.md#539-closechannel-client---server-server---client)
    - [5.3.10 SetExtranoncePrefix (Server -> Client)](./05-Mining-Protocol.md#5310-setextranonceprefix-server---client)
    - [5.3.11 SubmitSharesStandard (Client -> Server)](./05-Mining-Protocol.md#5311-submitsharesstandard-client---server)
    - [5.3.12 SubmitSharesExtended (Client -> Server)](./05-Mining-Protocol.md#5312-submitsharesextended-client---server)
    - [5.3.13 SubmitShares.Success (Server -> Client)](./05-Mining-Protocol.md#5313-submitsharessuccess-server---client)
    - [5.3.14 SubmitShares.Error (Server -> Client)](./05-Mining-Protocol.md#5314-submitshareserror-server---client)
    - [5.3.15 NewMiningJob (Server -> Client)](./05-Mining-Protocol.md#5315-newminingjob-server---client)
    - [5.3.16 NewExtendedMiningJob (Server -> Client)](./05-Mining-Protocol.md#5316-newextendedminingjob-server---client)
    - [5.3.17 SetNewPrevHash (Server -> Client, broadcast)](./05-Mining-Protocol.md#5317-setnewprevhash-server---client-broadcast)
    - [5.3.18 SetCustomMiningJob (Client -> Server)](./05-Mining-Protocol.md#5318-setcustomminingjob-client---server)
    - [5.3.19 SetCustomMiningJob.Success (Server -> Client)](./05-Mining-Protocol.md#5319-setcustomminingjobsuccess-server---client)
    - [5.3.20 SetCustomMiningJob.Error (Server -> Client)](./05-Mining-Protocol.md#5320-setcustomminingjoberror-server---client)
    - [5.3.21 SetTarget (Server -> Client)](./05-Mining-Protocol.md#5321-settarget-server---client)
    - [5.3.22 SetGroupChannel (Server -> Client)](./05-Mining-Protocol.md#5322-setgroupchannel-server---client)
- [6. Job Declaration Protocol](./06-Job-Declaration-Protocol.md)
  - [6.1 Job Declaration Protocol Messages](./06-Job-Declaration-Protocol.md#61-job-declaration-protocol-messages)
    - [6.1.1 SetupConnection Flags for Job Declaration Protocol](./06-Job-Declaration-Protocol.md#611-setupconnection-flags-for-job-declaration-protocol)
    - [6.1.2 AllocateMiningJobToken (Client -> Server)](./06-Job-Declaration-Protocol.md#612-allocateminingjobtoken-client---server)
    - [6.1.3 AllocateMiningJobToken.Success (Server -> Client)](./06-Job-Declaration-Protocol.md#613-allocateminingjobtokensuccess-server---client)
    - [6.1.4 CommitMiningJob (Client -> Server)](./06-Job-Declaration-Protocol.md#614-commitminingjob-client---server)
    - [6.1.5 CommitMiningJob.Success (Server -> Client)](./06-Job-Declaration-Protocol.md#615-commitminingjobsuccess-server---client)
    - [6.1.6 CommitMiningJob.Error (Server->Client)](./06-Job-Declaration-Protocol.md#616-commitminingjoberror-server-client)
    - [6.1.7 ProvideMissingTransactions (Server->Client)](./06-Job-Declaration-Protocol.md#619-providemissingtransactions-server-client)
    - [6.1.8 ProvideMissingTransactions.Success (Client->Server)](./06-Job-Declaration-Protocol.md#6110-providemissingtransactionssuccess-client-server)
- [7. Template Distribution Protocol](./07-Template-Distribution-Protocol.md)
  - [7.1 CoinbaseOutputConstraints (Client -> Server)](./07-Template-Distribution-Protocol.md#71-coinbaseoutputdatasize-client---server)
  - [7.2 NewTemplate (Server -> Client)](./07-Template-Distribution-Protocol.md#72-newtemplate-server---client)
  - [7.3 SetNewPrevHash (Server -> Client)](./07-Template-Distribution-Protocol.md#73-setnewprevhash-server---client)
  - [7.4 RequestTransactionData (Client -> Server)](./07-Template-Distribution-Protocol.md#74-requesttransactiondata-client---server)
  - [7.5 RequestTransactionData.Success (Server->Client)](./07-Template-Distribution-Protocol.md#75-requesttransactiondatasuccess-server-client)
  - [7.6 RequestTransactionData.Error (Server->Client)](./07-Template-Distribution-Protocol.md#76-requesttransactiondataerror-server-client)
  - [7.7 SubmitSolution (Client -> Server)](./07-Template-Distribution-Protocol.md#77-submitsolution-client---server)
- [8. Message Types](./08-Message-Types.md)
- [9. Extensions](./09-Extensions.md)
- [10. Discussion](./10-Discussion.md#10-discussion)
  - [10.1 Speculative Mining Jobs](./10-Discussion.md#101-speculative-mining-jobs)
  - [10.2 Rolling `nTime`](./10-Discussion.md#102-rolling-ntime)
    - [10.2.1 Hardware nTime rolling](./10-Discussion.md#1021-hardware-ntime-rolling)
  - [10.3 Notes](./10-Discussion.md#103-notes)
  - [10.4 Usage Scenarios](./10-Discussion.md#104-usage-scenarios)
    - [10.4.1 End Device (v2 ST)](./10-Discussion.md#1041-end-device-v2-st)
    - [10.4.2 Transparent Proxy (v2 any -> v2 any)](./10-Discussion.md#1042-transparent-proxy-v2-any---v2-any)
    - [10.4.3 Difficulty Aggregating Proxy (v2 any -> v2 EX)](./10-Discussion.md#1043-difficulty-aggregating-proxy-v2-any---v2-ex)
    - [10.4.4 Proxy (v1 -> v2)](./10-Discussion.md#1044-proxy-v1---v2)
    - [10.4.5 Proxy (v2 -> v1)](./10-Discussion.md#1045-proxy-v2---v1)
  - [10.5. FAQ](./10-Discussion.md#105-faq)
    - [10.5.1 Why is the protocol binary?](./10-Discussion.md#1051-why-is-the-protocol-binary)
  - [10.6 Terminology](./10-Discussion.md#106-terminology)
  - [10.7 Open Questions / Issues](./10-Discussion.md#107-open-questions--issues)

## Authors
Pavel Moravec <pavel@braiins.com>  
Jan Čapek <jan@braiins.com>  
Matt Corallo <bipstratum@bluematt.me>
