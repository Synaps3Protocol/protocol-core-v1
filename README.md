
[![CI](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml/badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)
[![COV](https://raw.githubusercontent.com/Synaps3Protocol/protocol-core-v1/main/.github/workflows/cov-badge.svg)](https://github.com/Synaps3Protocol/protocol-core-v1/actions/workflows/ci.yaml)

# Synapse Protocol
Welcome! 🎉 Synapse is redefining how creative IP distribution works. Whether it's films, music, or games, we ensure creators stay in control of their work while earning fairly. With the power of blockchain, Synapse eliminates middlemen and automates licensing, payments, and content delivery through smart contracts. This lets creators focus on their craft, knowing their content is distributed safely and transparently.

## System Overview

The architecture is structured into distinct layers, starting from interaction and execution at the top and progressing down to the foundational governance layer:

![image](https://github.com/user-attachments/assets/a567d283-90cc-4b71-8f0b-83ee207dab07)

### Operational Layer
The topmost layer comprises **Finance**, **Apps**, and **Distribution Network**, which interact directly with the validated framework.
- **Finance** handles agreements, settlements, and economic interactions.
- **Apps** provide user-facing interfaces.
- **Distribution Network** ensures the secure distribution of assets to authorized parties.

### Rights and Policies
Beneath the operational layer:
- **Rights** manages access, custody, and usage of assets, ensuring compliance with validated distributors and governance rules.
- **Policies** define the terms, conditions, and operational frameworks governing assets and their distribution.

### Assets and Distribution Management
- **Syndication** oversees the network of distributors, validating and authorizing them as custodians of assets.
- **Assets** manage the registration and validation of resources entering the system, ensuring proper control and compliance with system policies.

### Foundational Governance
At the base, **Economics**, **Governance**, and **Access Control** govern and sustain the entire protocol.
- **Economics** ensures financial stability through treasury management, tokens, and tollgates.
- **Governance** establishes rules and strategic decisions.
- **Access Control** enforces these rules by managing permissions and roles across all layers.

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
