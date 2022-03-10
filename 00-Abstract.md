# 0. Abstract
The current stratum protocol (v1) is used prevalently throughout the cryptocurrency mining industry today, but it was never intended nor designed to be an industry standard.   

This document proposes a new version of stratum protocol that addresses scaling and quality issues of the previous version, focusing on more efficient data transfers (i.e. distribution of mining jobs and result submissions) as well as increased security.

Additionally, the redesigned protocol includes support for transaction selection by the miners themselves, as opposed to the current version of the protocol in which only the pool operators can determine a new block’s transaction set.

There are some trade offs necessary to make the protocol scalable and relatively simple, which will be addressed in the detailed discussions below.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC2119.

We keep the name "Stratum" so that people will recognize that this is an upgrade of the widespread protocol version 1, with the hope that it will help gather support for the new version more easily. 
