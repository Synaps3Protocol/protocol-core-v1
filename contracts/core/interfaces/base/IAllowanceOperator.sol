// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IAllowanceOperator Interface
/// @notice Combines functionalities for verifying, approving, revoking, and collecting allowances.
/// @dev This interface aggregates multiple interfaces to standardize allowance-related operations.
import { IAllowanceVerifiable } from "@synaps3/core/interfaces/base/IAllowanceVerifiable.sol";
import { IAllowanceCollectable } from "@synaps3/core/interfaces/base/IAllowanceCollectable.sol";
import { IAllowanceApprovable } from "@synaps3/core/interfaces/base/IAllowanceApprovable.sol";
import { IAllowanceRevokable } from "@synaps3/core/interfaces/base/IAllowanceRevokable.sol";

/// @dev The `IAllowanceOperator` interface extends multiple interfaces to provide a comprehensive suite of
/// allowance-related operations, including approval, revocation, collection, and allowance verification.
interface IAllowanceOperator is
    IAllowanceApprovable,
    IAllowanceRevokable,
    IAllowanceCollectable,
    IAllowanceVerifiable
{}
