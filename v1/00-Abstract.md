# 0. Abstract
The current stratum protocol (v1) is used prevalently throughout the cryptocurrency mining industry, but it was never intended nor designed to be an industry standard. Also, as of 2024, there is fragmentation, lack of standardization and industry player are already working on protocol improvements.

This document aims to provide a formal specification of the stratum v1 protocol, as well as standardize optimizations done by industry players over the course of 2024. These optimizations improve the v1 protocol while addressing scaling and quality issues of the previous version, focusing on more efficient data transfers (i.e. distribution of mining jobs and result submissions) as well as increased security.

This document also aims to be in full alignment with [BIP41](https://todo).

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC2119.