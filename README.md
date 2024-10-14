# Core (WIP)
![image](https://github.com/user-attachments/assets/2a599bc4-a876-486a-a35a-711c880cf3e4)

# Overview
The Synapse Protocol revolutionizes the management and distribution of creative intellectual property (IP) using blockchain technology and smart contracts. It provides a decentralized framework for content monetization across formats such as films, music, games, and more.

# Key Features
Decentralized IP Monetization: Enable creators to maintain ownership while exploring custom business models (e.g., rentals, purchases).
Rights Management & Enforcement: Use smart contracts to handle licensing, compliance, and royalty distribution transparently.
Interoperability: Integrates seamlessly with protocols such as Story Protocol to expand IP management potential.


MMC: 0x21173483074a46c302c4252e04c76fA90e6DdA6C


Cnv:
    guidelines for emitting events
    - Any function that can change a storage variable should emit an event.
    - The event should contain enough information for someone auditing the logs can determine what value the storage variable took at that time.
    - Any address parameters in the event should be indexed so that it is easy to drill down on the activity of a particular wallet.
    - View and pure functions should not contain events because they do not change the state.

refs:

https://github.com/crytic/building-secure-contracts/blob/master/development-guidelines/code_maturity.md

https://docs.soliditylang.org/en/latest/style-guide.html











