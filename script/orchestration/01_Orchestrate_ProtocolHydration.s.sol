// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IAccessManager } from "contracts/interfaces/access/IAccessManager.sol";
import { ITollgate } from "contracts/interfaces/economics/ITollgate.sol";
import { C } from "contracts/libraries/Constants.sol";
import { T } from "contracts/libraries/Types.sol";

import { DeployTollgate } from "script/deployment/04_Deploy_Economics_Tollgate.s.sol";
import { DeployTreasury } from "script/deployment/05_Deploy_Economics_Treasury.s.sol";
import { DeployContentReferendum } from "script/deployment/06_Deploy_Content_ContentReferendum.s.sol";
import { DeployDistributorReferendum } from "script/deployment/10_Deploy_Syndication_DistributorReferendum.s.sol";
import { DeployPolicyAudit } from "script/deployment/11_Deploy_Policies_PolicyAudit.s.sol";
import { Treasury } from "contracts/economics/Treasury.sol";
import { PolicyAudit } from "contracts/policies/PolicyAudit.sol";

import { getGovPermissions as TollgateGovPermissions } from "script/permissions/Permissions_Tollgate.sol";
import { getGovPermissions as TreasuryGovPermissions } from "script/permissions/Permissions_Treasury.sol";
import { getGovPermissions as PolicyAuditorGovPermissions } from "script/permissions/Permissions_PolicyAuditor.sol";
import { getGovPermissions as DistributorReferendumGovPermissions } from "script/permissions/Permissions_DistributorReferendum.sol";
import { getGovPermissions as ContentReferendumGovPermissions } from "script/permissions/Permissions_ContentReferendum.sol";

contract OrchestrateProtocolHydration is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address tollgateAddress = vm.envAddress("TOLLGATE");
        address treasuryAddress = vm.envAddress("TREASURY");
        address auditorAddress = vm.envAddress("POLICY_AUDIT");
        address contentReferendumAddress = vm.envAddress("CONTENT_REFERENDUM");
        address distributorReferendumAddress = vm.envAddress("DISTRIBUTION_REFERENDUM");
        address accessManager = vm.envAddress("ACCESS_MANAGER");

        vm.startBroadcast(admin);
        // 1 set the initial governor to operate over the protocol configuration
        // initially the admin will have the role of "governor"
        // initailly the admin will be the mod to setup policies
        address adminAddress = vm.addr(admin);
        IAccessManager authority = IAccessManager(accessManager);
        // the governor is set to admin to handle initial setup..
        // after this can be revoked and assign the governance as governor
        authority.grantRole(C.GOV_ROLE, adminAddress, 0);

        // assign governance permissions
        bytes4[] memory tollgateAllowed = TollgateGovPermissions();
        bytes4[] memory treasuryAllowed = TreasuryGovPermissions();
        bytes4[] memory auditorAllowed = PolicyAuditorGovPermissions();
        bytes4[] memory contentReferendumAllowed = ContentReferendumGovPermissions();
        bytes4[] memory distributorReferendumAllowed = DistributorReferendumGovPermissions();

        authority.setTargetFunctionRole(tollgateAddress, tollgateAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(treasuryAddress, treasuryAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(auditorAddress, auditorAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(contentReferendumAddress, contentReferendumAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(distributorReferendumAddress, distributorReferendumAllowed, C.GOV_ROLE);

        // 2 set mmc as the initial currency and fees
        uint256 rmaFees = vm.envUint("AGREEMENT_FEES"); // 5% 500 bps
        uint256 synFees = vm.envUint("SYNDICATION_FEES"); // 100 MMC flat fee
        address mmcAddress = vm.envAddress("MMC");

        ITollgate tollgate = ITollgate(tollgateAddress);
        tollgate.setFees(T.Context.RMA, rmaFees, mmcAddress);
        tollgate.setFees(T.Context.SYN, synFees, mmcAddress);

        require(tollgate.getFees(T.Context.RMA, mmcAddress) == rmaFees, "Invalid RMA Fees Set");
        require(tollgate.getFees(T.Context.SYN, mmcAddress) == synFees, "Invalid SYN Fees Set");

        vm.stopBroadcast();
    }
}
