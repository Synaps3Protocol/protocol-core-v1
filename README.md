
[![CI](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)
[![COV](https://raw.githubusercontent.com/Synaps3Protocol/protocol-core-v1/main/.github/workflows/cov-badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)

# Synapse Protocol
A decentralized infrastructure for governing digital content through verifiable licensing, programmable distribution, and automated monetization. Designed for creators across film, music, photography, books, gaming, and all forms of digital creative expression, the protocol ensures sovereign control and fair economic participation without relying on centralized platforms. By replacing discretionary decisions with deterministic smart contract execution, it guarantees secure content access, transparent rights enforcement, and trustless revenue flows.

## System Overview

The architecture is composed of three modular layers, each with distinct responsibilities:

![image](https://github.com/user-attachments/assets/a1b2ead5-c1ff-48df-b48b-ff5d46762ac1)

### Level 3 — Rights Management
Executes deterministic policy enforcement in real time, ensuring strict compliance with approved access and usage conditions.

- **Rights:** Enforces access and custody conditions at runtime by resolving permissions and validating compliance against approved policies.

### Level 2 — Operational Layer: Assets, Policies, Custody & Finance
Coordinates asset lifecycle, programmable policies, decentralized custody, and financial execution under governance-defined logic.

- **Assets:** Registers and validates content ownership and structure, anchoring assets to creators and associated policies.  
- **Custody:** Manages registration and validation of custodians, ensuring policy-compliant content delivery.  
- **Finance:** Executes agreements, settlements, and payouts under policy-bound logic and integrated vault management.  
- **Policies:** Defines, audits, and governs licensing, access, and monetization rules through reusable programmable templates.  

### Level 1 — Foundational Governance
Establishes protocol-wide rules for economic coordination, systemic permissioning, and controlled evolution.

- **Economics:** Manages the token model, treasury, and tollgate mechanisms to align incentives and access with protocol sustainability.  
- **Governance:** Coordinates protocol upgrades, policy approvals, and system evolution via proposals, voting, and execution.  
- **Access Control:** Defines and enforces role-based permissions and authorization rules across all protocol components.  
- **Lifecycle:** Enables modular extensibility through hooks and scheduled transitions governed by formal approval.  

## Contributing
Have feedback, ideas, or found a bug?  
Start a discussion or open a pull request — contributions are welcome and encouraged.

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
