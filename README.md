
[![CI](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)
[![COV](https://raw.githubusercontent.com/Synaps3Protocol/protocol-core-v1/main/.github/workflows/cov-badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)

# Synapse Protocol
Welcome! 🎉 Synapse is redefining how creative IP distribution works. Whether it's films, music, or games, we ensure creators stay in control of their work while earning fairly. With the power of blockchain, Synapse eliminates middlemen and automates licensing, payments, and content delivery through smart contracts. This lets creators focus on their craft, knowing their content is distributed safely and transparently.

## System Overview

The protocol is composed of three hierarchical layers, each with a clear domain of responsibility, from foundational governance to operational logic and enforcement.:

![image](https://github.com/user-attachments/assets/a1b2ead5-c1ff-48df-b48b-ff5d46762ac1)


### Level 3 — Rights Management
Responsible for enforcing the permitted usage of registered assets. Ensures that access and custody align with validated custodians and protocol-defined policies.

- **Rights**: Governs access permissions, usage conditions, and custody validation for each asset instance.

### Level 2 — Operational Layer: Asset, Custody, Policy & Finance
Manages the lifecycle and structure of content and its distribution logic across the network.

- **Assets**: Handles the registration, canonicalization, and verification of content entering the system.
- **Custody**: Manages custodian nodes, including their validation, assignment, and operational state.
- **Policies**: Defines the programmable terms, usage rights, and distribution logic governing assets.
- **Finance**: Oversees revenue sharing, payouts, agreements, and settlements.

### Level 1 — Foundational Governance
Anchored by protocol governance, this layer provides economic coordination, lifecycle management, and permissioning for all protocol actors.

- **Governance**: Maintains strategic decisions, upgrade paths, and protocol-wide parameters.
- **Economics**: Administers the token model, treasury, and economic tollgates for access and incentives.
- **Access Control**: Enforces role-based permissions, membership rules, and delegated authorities.
- **Lifecycle**: Introduces programmable hooks, temporal constraints, and modular behaviors through scheduled actions and state transitions.


## Join the Fun
Found a bug? Got a cool idea? Open a pull request or start a discussion on GitHub. We’d love to build this together!

## Development

Some available capabilities for dev support:

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
