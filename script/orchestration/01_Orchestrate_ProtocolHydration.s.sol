// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import "forge-std/Script.sol";

import { IAccessManager } from "contracts/core/interfaces/access/IAccessManager.sol";
import { ITollgate } from "contracts/core/interfaces/economics/ITollgate.sol";
import { C } from "contracts/core/primitives/Constants.sol";
import { T } from "contracts/core/primitives/Types.sol";

import { getGovPermissions as TollgateGovPermissions } from "script/permissions/Permissions_Tollgate.sol";
import { getGovPermissions as TreasuryGovPermissions } from "script/permissions/Permissions_Treasury.sol";
import { getGovPermissions as CustodianReferendumGovPermissions } from "script/permissions/Permissions_CustodianReferendum.sol";
import { getGovPermissions as AssetReferendumGovPermissions } from "script/permissions/Permissions_AssetReferendum.sol";
import { getModPermissions as PolicyAuditorModPermissions } from "script/permissions/Permissions_PolicyAuditor.sol";
import { getOpsPermissions as LedgerVaultOpsPermissions } from "script/permissions/Permissions_LedgerVault.sol";
import { getModPermissions as HooksModPermissions } from "script/permissions/Permissions_HookRegistry.sol";
import { getPauserPermissions as PauserPermissions } from "script/permissions/Permissions_AccessControlled.sol";

contract OrchestrateProtocolHydration is Script {
    function run() external {
        uint256 admin = vm.envUint("PRIVATE_KEY");
        address tollgateAddress = vm.envAddress("TOLLGATE");
        address treasuryAddress = vm.envAddress("TREASURY");
        address auditorAddress = vm.envAddress("POLICY_AUDIT");
        address accessManager = vm.envAddress("ACCESS_MANAGER");
        address assetRegistry = vm.envAddress("ASSET_REGISTRY");
        address assetReferendum = vm.envAddress("ASSET_REFERENDUM");
        address agreementManager = vm.envAddress("AGREEMENT_MANAGER");
        address agreementSettler = vm.envAddress("AGREEMENT_SETTLER");
        address rightPolicyManager = vm.envAddress("RIGHT_POLICY_MANAGER");
        address custodianReferendum = vm.envAddress("CUSTODIAN_REFERENDUM");
        address ledgerVault = vm.envAddress("LEDGER_VAULT");

        vm.startBroadcast(admin);
        // 1 set the initial governor to operate over the protocol configuration
        // initially the admin will have the role of "governor"
        // initially the admin will be the mod to setup policies
        address adminAddress = vm.addr(admin);
        IAccessManager authority = IAccessManager(accessManager);

        // the governor is set to admin to handle initial setup..
        // after this can be revoked and assign the governance timelock as governor
        // https://docs.openzeppelin.com/contracts/5.x/access-control#role-admins-and-guardians
        authority.grantRole(C.GOV_ROLE, adminAddress, 0);

        authority.grantRole(C.OPS_ROLE, agreementManager, 0);
        authority.grantRole(C.OPS_ROLE, agreementSettler, 0);

        // assign governance permissions
        bytes4[] memory pauserAllowed = PauserPermissions();
        bytes4[] memory vaultAllowed = LedgerVaultOpsPermissions();
        bytes4[] memory tollgateAllowed = TollgateGovPermissions();
        bytes4[] memory treasuryAllowed = TreasuryGovPermissions();
        bytes4[] memory auditorAllowed = PolicyAuditorModPermissions();
        bytes4[] memory assetReferendumAllowed = AssetReferendumGovPermissions();
        bytes4[] memory custodianReferendumAllowed = CustodianReferendumGovPermissions();

        // pausable list of contracts
        authority.setTargetFunctionRole(assetRegistry, pauserAllowed, C.SEC_ROLE);
        authority.setTargetFunctionRole(ledgerVault, pauserAllowed, C.SEC_ROLE);
        authority.setTargetFunctionRole(treasuryAddress, pauserAllowed, C.SEC_ROLE);
        authority.setTargetFunctionRole(custodianReferendum, pauserAllowed, C.SEC_ROLE);

        authority.setTargetFunctionRole(tollgateAddress, tollgateAllowed, C.GOV_ROLE);
        authority.setTargetFunctionRole(treasuryAddress, treasuryAllowed, C.GOV_ROLE);

        authority.setTargetFunctionRole(treasuryAddress, treasuryAllowed, C.TREASURER_ROLE);
        authority.setTargetFunctionRole(assetReferendum, assetReferendumAllowed, C.CONTENT_COUNCIL_ROLE);
        authority.setTargetFunctionRole(custodianReferendum, custodianReferendumAllowed, C.CUSTODY_COUNCIL_ROLE);

        authority.setTargetFunctionRole(ledgerVault, vaultAllowed, C.OPS_ROLE);
        authority.setTargetFunctionRole(auditorAddress, auditorAllowed, C.ADMIN_ROLE);
        // bytes4[] memory hookModAllowed = HooksModPermissions();
        // authority.setTargetFunctionRole(auditorAddress, hookModAllowed, C.MOD_ROLE);

        // 2 set mmc as the initial currency and fees
        uint256 agrFee = vm.envUint("AGREEMENT_FEES"); // 5% 500 bps
        address currency = vm.envAddress("MMC");

        ITollgate tollgate = ITollgate(tollgateAddress);
        // assign bps scheme to right policy manager + fees + mmc
        tollgate.setFees(T.Scheme.BPS, rightPolicyManager, agrFee, currency);

        (uint256 feeA, ) = tollgate.getFees(rightPolicyManager, currency);
        require(feeA == agrFee);
        vm.stopBroadcast();
    }
}
