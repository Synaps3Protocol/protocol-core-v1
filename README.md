
[![CI](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)
[![COV](https://raw.githubusercontent.com/Synaps3Protocol/protocol-core-v1/main/.github/workflows/cov-badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)

# Synapse Protocol
Synapse Protocol is a modular, chain-agnostic infrastructure designed for sovereign control over digital content rights, licensing, and monetization. Targeted at creators across film, music, games, photography, and literature, Synapse enables secure content access, deterministic policy enforcement, and automated revenue flows, without relying on centralized platforms.

## Architecture Overview

Synapse is built on a **three-layer modular architecture**, ensuring scalability, verifiability, and extensibility:
![image](https://github.com/user-attachments/assets/a1b2ead5-c1ff-48df-b48b-ff5d46762ac1)
| Layer | Responsibilities |
| --- | --- |
| **Layer 3 — Rights Management** | Real-time, policy-bound enforcement of rights and content access. |
| **Layer 2 — Operational Coordination** | Asset registration, policy governance, custody assignment, and programmable finance. |
| **Layer 1 — Foundational Governance** | Tokenomics, protocol governance, role-based access control, and lifecycle management. |

## Contributing
We welcome feedback, feature requests, and contributions:
- Start a [discussion](https://github.com/Synaps3Protocol/protocol-core-v1/discussions)
- Report issues via [GitHub Issues](https://github.com/Synaps3Protocol/protocol-core-v1/issues)
- Submit a [Pull Request](https://github.com/Synaps3Protocol/protocol-core-v1/pulls)
  
## Developer Quickstart
Use the following commands to test, compile, and audit the protocol:

* **Run Tests**: `make test`  
* **Compile Contracts**: `make compile`  
* **Force Compile Contracts**: `make force-compile`  
* **Test Coverage Report**: `make coverage`  
* **Generate Security Report**: `make secreport`  
* **Run Security Tests**: `make sectest`  
* **Format Code**: `make format`  
* **Lint Code**: `make lint`   

Note: Run `make help` to see additional capabilities.

## References

- Code Maturity: https://github.com/crytic/building-secure-contracts/blob/master/development-guidelines/code_maturity.md
- Style Guide: https://docs.soliditylang.org/en/latest/style-guide.html
