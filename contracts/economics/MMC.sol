// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// https://eips.ethereum.org/EIPS/eip-2612 - permit
// https://eips.ethereum.org/EIPS/eip-1363 - payable
// TODO upgradeable feature + DAO

/// @title Multimedia Coin (MMC)
/// @notice ERC20 token with governance and permit functionality.
/// @dev Implements ERC20Votes, and ERC20Permit for advanced functionality.
contract MMC is ERC20, ERC20Permit, ERC20Votes {
    constructor(
        address initialHolder,
        uint256 totalSupply
    ) ERC20("Multimedia Coin", "MMC") ERC20Permit("Multimedia Coin") {
        _mint(initialHolder, totalSupply * (10 ** 18));
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        return super._update(from, to, value);
    }
}
