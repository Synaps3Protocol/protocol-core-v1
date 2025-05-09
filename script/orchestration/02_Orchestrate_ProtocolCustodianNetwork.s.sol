// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import { DeployBase } from "script/deployment/00_Deploy_Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILedgerVault } from "contracts/core/interfaces/financial/ILedgerVault.sol";
import { ICustodian } from "contracts/core/interfaces/custody/ICustodian.sol";
import { ICustodianFactory } from "contracts/core/interfaces/custody/ICustodianFactory.sol";
import { ICustodianReferendum } from "contracts/core/interfaces/custody/ICustodianReferendum.sol";
import { IAgreementManager } from "contracts/core/interfaces/financial/IAgreementManager.sol";

contract OrchestrateProtocolCustodianNetwork is DeployBase {
    function run() external {
        uint256 admin = getAdminPK();
        address mmc = vm.envAddress("MMC");
        uint256 fees = vm.envUint("CUSTODY_FEES"); // 100 MMC flat fee
        address vault = computeCreate3Address("SALT_LEDGER_VAULT");
        address custodianFactory = vm.envAddress("CUSTODIAN_FACTORY");
        address custodianReferendum = vm.envAddress("CUSTODIAN_REFERENDUM");
        address agreementManager = vm.envAddress("AGREEMENT_MANAGER");

        vm.startBroadcast(admin);
        // approve initial custodian
        address custodian = ICustodianFactory(custodianFactory).create("https://g.watchit.movie");
        ICustodianReferendum referendum = ICustodianReferendum(custodianReferendum);

        bytes32 got = keccak256(abi.encodePacked(ICustodian(custodian).getEndpoint()));
        bytes32 expected = keccak256(abi.encodePacked("https://g.watchit.movie"));

        require(ICustodian(custodian).getManager() == vm.addr(admin));
        require(got == expected);

        // deposit funds to register custodian
        IERC20(mmc).approve(vault, fees);
        ILedgerVault(vault).deposit(vm.addr(admin), fees, mmc);
        ILedgerVault(vault).approve(address(referendum), fees, mmc);

        address custody = address(custodian);
        address[] memory parties = new address[](1);
        parties[0] = custody;

        uint256 proof = IAgreementManager(agreementManager).createAgreement(
            fees,
            mmc,
            address(referendum),
            parties,
            ""
        );

        referendum.register(proof, address(custodian));
        referendum.approve(address(custodian));
        vm.stopBroadcast();

        _logAddress("DEFAULT_CUSTODIAN_ADDRESS", custodian);
    }
}
