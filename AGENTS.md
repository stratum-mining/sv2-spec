# AGENTS.md

This file provides guidance for agents working on this repository. It is committed to the repository, which means agents from all contributors follow the same conventions.

Contributors are free to add their own custom guidance for their agents via `AGENTS_CUSTOM.md`, which is NOT committed to the repository.

### Stratum V2 Specification

This repository contains the canonical source of truth of the English Specification (Spec) of the next-gen protocol for Bitcoin mining called **Stratum V2**.

It is hosted at [https://github.com/stratum-mining/sv2-spec](https://github.com/stratum-mining/sv2-spec), where the SRI community contributes on improvements to the repository.

References:
- https://stratumprotocol.org
- https://braiins.com/blog/past-and-future-of-bitcoin-mining-protocols-stratum-v2-overview
- https://academy.braiins.com/braiins-pool/stratum-v2-manual
- https://webthesis.biblio.polito.it/27678/
- https://bitcoinmagazine.com/glossary/stratum-v2

### Stratum V2 Reference Implementation (SRI)

The Stratum V2 Specification, as well as the Reference Implementation of Stratum V2 (SRI) are available at the following github organization.

Aside from [`sv2-spec`](https://github.com/stratum-mining/sv2-spec), the following repositories compose the body of SRI:
- [`stratum`](https://github.com/stratum-mining/stratum): low-level spec-compliant libraries as Rust crates, under `stratum-core` umbrella crate.
- [`sv2-apps`](https://github.com/stratum-mining/sv2-apps): high-level spec-compliant applications as Rust crates (with `tokio` as async runtime).
- [`sv2-ui`](https://github.com/stratum-mining/sv2-ui): a web-based UI orchestrating containerized local deployments of `sv2-apps`.
- [`sv2-tp`](https://github.com/stratum-mining/sv2-tp): a C++ implementation of a Sv2 Template Provider application, deployable as a sidecar for Bitcoin Core.
- [`sv2-uniffi`](https://github.com/stratum-mining/sv2-uniffi): a Rust/Uniffi wrapper around `stratum` core libraries, providing C++ and Python bindings.

### Sv2 community

The Sv2 community is composed of:
- Bitcoin Mining Industry players investing resources into Stratum V2 adoption.
- FOSS-funded individual contributors working on SRI (SRI community).

Together they reach consensus on what the Stratum V2 specification is (using this repository as the canonical source of truth).

### Contribution workflow

The SRI project follows an open contributor model, where anyone is welcome to contribute through reviews, documentation, testing, and patches. Follow these steps to contribute:

1. **Fork the Repository**

2. **Create a Branch**

3. **Make Your Changes**

4. **Commit Your Changes**

    These guidelines should be kept in mind:
    - Progressive commit history, with clear separation of concerns.
    - Avoid individual commits that address specific review findings, which breaks commit history cohesion. Always fold review findings into the original commit.
    - Commit messages should provide a clear and concise explanation of the solution's rationale.
    - If the specific commit closes some specific github issue, include the issue URL in the commit message.
    - If possible, sign your commits with your GPG key.
    - Writing style: [chris.beams.io/posts/git-commit](https://chris.beams.io/posts/git-commit/)
    - Structure: [conventionalcommits.org](https://www.conventionalcommits.org/)

5. **Submit a Pull Request**

    Once you're satisfied with your changes, submit a pull request to the original SRI repository. Provide a clear and concise description of the changes you've made. If your pull request addresses an existing issue, reference the issue number in the description. In order to contribute to the protocol implementation, every PR must be opened against `main` branch.

6. **Review and Iterate**

7. **Merge and Close**

    Once your pull request has been approved and all discussions have been resolved, a project maintainer will merge your changes into the `main` branch. Your contribution will then be officially part of the project. The pull request will be closed, marking the completion of your contribution.
