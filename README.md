
[![CI](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)
[![COV](https://raw.githubusercontent.com/Synaps3Protocol/protocol-core-v1/main/.github/workflows/cov-badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)

# Synapse Protocol
Welcome! 🎉 Synapse is redefining how creative IP distribution works. Whether it's films, music, or games, we ensure creators stay in control of their work while earning fairly. With the power of blockchain, Synapse eliminates middlemen and automates licensing, payments, and content delivery through smart contracts. This lets creators focus on their craft, knowing their content is distributed safely and transparently.

## System Overview

The architecture is structured into distinct layers, starting from interaction and execution at the top and progressing down to the foundational governance layer:

![image](https://github.com/user-attachments/assets/32b06a9d-186c-4d2f-b8bf-760cf3068de4)

### Level 3: Rights and Policies
- **Rights**: Manages access, custody, and usage of assets, ensuring they align with validated custodians and governance rules.
- **Policies**: Defines the terms, conditions, and operational frameworks governing assets and their distribution.
 
### Level 2: Assets and Distribution Management
- **Custody**: Oversees the network of custodians, validating and authorizing them as custodians of assets.
- **Assets**: Manages the registration and validation of resources entering the system, ensuring compliance with governance policies.
- **Finance**: Handles agreements, settlements, and economic interactions.

### Level 1: Foundational Governance
- **Economics**: Ensures financial stability through treasury management, tokens, and tollgates.
- **Governance**: Establishes the rules and strategic decisions for the entire protocol.
- **Access Control**: Enforces governance rules by managing permissions and roles across all layers.
- **Lifecycle**: Introduces programmable hooks, time-based triggers, and scheduled actions that enable composable and modular protocol behavior.


---

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
