pragma solidity 0.8.26;

import "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IDistributor } from "contracts/interfaces/syndication/IDistributor.sol";
import { BaseTest } from "test/BaseTest.t.sol";

contract DistributorImplTest is BaseTest {

    function test_Create_ValidDistributor() public {
        address distributor = deployDistributor("test.com");
        assertEq(IERC165(distributor).supportsInterface(type(IDistributor).interfaceId), true);
        assertEq(IDistributor(distributor).getEndpoint(), "test.com");
    }
}
