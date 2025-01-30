// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IERC721StatefulSwitchable
/// @notice Extension of IERC721Stateful that allows switching an asset's activation state.
/// @dev This interface provides a function to switch an asset's state between active and inactive.
interface IERC721StatefulSwitchable {
    /// @notice Switches the activation state of an asset.
    /// @dev If the asset is active, it becomes inactive; if inactive, it becomes active.
    /// @param assetId The ID of the asset whose state is being changed.
    /// @return newState The updated state of the asset (`true` for active, `false` for inactive).
    function switchState(uint256 assetId) external returns (bool newState);
}
