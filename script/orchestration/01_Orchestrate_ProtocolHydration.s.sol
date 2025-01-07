// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { C } from "contracts/core/primitives/Constants.sol";
import { T } from "contracts/core/primitives/Types.sol";

import { getGovPermissions as TollgateGovPermissions } from "script/permissions/Permissions_Tollgate.sol";
import { getGovPermissions as TreasuryGovPermissions } from "script/permissions/Permissions_Treasury.sol";
import { getGovPermissions as DistributorReferendumGovPermissions } from "script/permissions/Permissions_DistributorReferendum.sol";
import { getGovPermissions as AssetReferendumGovPermissions } from "script/permissions/Permissions_AssetReferendum.sol";
import { getModPermissions as PolicyAuditorModPermissions } from "script/permissions/Permissions_PolicyAuditor.sol";
import { getOpsPermissions as LedgerVaultOpsPermissions } from "script/permissions/Permissions_LedgerVault.sol";

contract OrchestrateProtocolHydration is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address tollgateAddress = vm.envAddress("TOLLGATE");
        address treasuryAddress = vm.envAddress("TREASURY");
        address auditorAddress = vm.envAddress("POLICY_AUDIT");
        address assetReferendum = vm.envAddress("ASSET_REFERENDUM");
        address rightPolicyManager = vm.envAddress("RIGHT_POLICY_MANAGER");
        address accessManager = vm.envAddress("ACCESS_MANAGER");
        address agreementManager = vm.envAddress("AGREEMENT_MANAGER");
        address agreementSettler = vm.envAddress("AGREEMENT_SETTLER");
        address distributorReferendum = vm.envAddress("DISTRIBUTION_REFERENDUM");
        address ledgerVault = vm.envAddress("LEDGER_VAULT");

        vm.startBroadcast(admin);
        // 1 set the initial governor to operate over the protocol configuration
        // initially the admin will have the role of "governor"
        // initially the admin will be the mod to setup policies
        address adminAddress = vm.addr(admin);
        IAccessManager authority = IAccessManager(accessManager);
        // the governor is set to admin to handle initial setup..
        // after this can be revoked and assign the governance as governor
        authority.grantRole(C.GOV_ROLE, adminAddress, 0);

        // assign governance permissions
        bytes4[] memory tollgateAllowed = TollgateGovPermissions();
        bytes4[] memory treasuryAllowed = TreasuryGovPermissions();
        bytes4[] memory assetReferendumAllowed = AssetReferendumGovPermissions();
        bytes4[] memory distributorReferendumAllowed = DistributorReferendumGovPermissions();

        authority.setTargetFunctionRole(tollgateAddress, tollgateAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(treasuryAddress, treasuryAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(assetReferendum, assetReferendumAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(distributorReferendum, distributorReferendumAllowed, C.GOV_ROLE);

        // assign moderation permissions
        authority.grantRole(C.MOD_ROLE, adminAddress, 0);
        bytes4[] memory auditorAllowed = PolicyAuditorModPermissions();
        authority.setTargetFunctionRole(auditorAddress, auditorAllowed, C.MOD_ROLE);

        // assign operations permissions
        authority.grantRole(C.OPS_ROLE, agreementManager, 0);
        authority.grantRole(C.OPS_ROLE, agreementSettler, 0);
        authority.grantRole(C.OPS_ROLE, distributorReferendum, 0);
        bytes4[] memory vaultAllowed = LedgerVaultOpsPermissions();
        authority.setTargetFunctionRole(ledgerVault, vaultAllowed, C.OPS_ROLE);

        // 2 set mmc as the initial currency and fees
        uint256 agrFee = vm.envUint("AGREEMENT_FEES"); // 5% 500 bps
        uint256 synFees = vm.envUint("SYNDICATION_FEES"); // 100 MMC flat fee
        address currency = vm.envAddress("MMC");

        ITollgate tollgate = ITollgate(tollgateAddress);
        // assign bps scheme to right policy manager + fees + mmc
        tollgate.setFees(T.Scheme.BPS, rightPolicyManager, agrFee, currency);
        tollgate.setFees(T.Scheme.FLAT, distributorReferendum, synFees, currency);

        require(tollgate.getFees(T.Scheme.BPS, rightPolicyManager, currency) == agrFee, "Invalid BPS Fees Set");
        require(tollgate.getFees(T.Scheme.FLAT, distributorReferendum, currency) == synFees, "Invalid Flat Fees Set");

        vm.stopBroadcast();
    }
}
