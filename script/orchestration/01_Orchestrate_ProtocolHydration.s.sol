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

contract OrchestrateProtocolHydration is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address tollgateAddress = vm.envAddress("TOLLGATE");
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

        // // tollgate grant access to governacne
        // (new DeployTollgate()).setUpPermissions();
        // (new DeployTreasury()).setUpPermissions();
        // (new DeployPolicyAudit()).setUpPermissions();
        // (new DeployContentReferendum()).setUpPermissions();
        // (new DeployDistributorReferendum()).setUpPermissions();

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
