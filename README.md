# Core (WIP)
![image](https://github.com/user-attachments/assets/3e480196-10c5-4324-b664-81839f8ca1f3)


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











