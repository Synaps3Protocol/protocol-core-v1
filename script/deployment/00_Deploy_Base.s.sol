// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CREATE3Factory, ICREATE3Factory } from "script/create3/CREATE3Factory.sol";

// https://github.com/ZeframLou/create3-factory/tree/main
// A CREATE3 factory offers the best solution: the address of the deployed contract
// is determined by only the deployer address and the salt.
// This makes it far easier to deploy contracts to multiple chains at the same addresses.
abstract contract DeployBase is Script {
    function getCreate3FactoryAddress() public view returns (address) {
        return vm.envAddress("CREATE3_FACTORY");
    }

    function getAdminPK() public view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    // https://eips.ethereum.org/EIPS/eip-1167
    function getSalt(string memory saltIndex) public view returns (bytes32) {
        return keccak256(abi.encodePacked(vm.envUint(saltIndex)));
    }

    function computeCreate3Address(string memory saltIndex) public view returns (address) {
        // The deployer of any contract is the CREATE3 factory,
        // and the deployer of the factory is expected to be the admin (msg.sender).
        // Based on this, we can predict the CREATE2 address for both the factory and the contracts.
        // factoryAddress = CREATE2 = keccak256(0xff ++ msg.sender ++ salt ++ keccak256(factoryBytecode))[12:]
        address factoryAddress = getCreate3FactoryAddress();

        // Next, we predict the CREATE3 address for contracts:
        // Internally, a minimal proxy is created to deploy the contract and receive the init code.
        // The proxy is deployed via CREATE2, meaning its address only depends on the factory’s address and the salt.
        // proxyAddress = CREATE2 = keccak256(0xff ++ factoryAddress ++ salt ++ keccak256(PROXY_INITCODE))[12:]

        // The actual contract is deployed via CREATE, so its address depends on the proxy's address and its nonce.
        // Since the proxy is newly deployed, its nonce is definitively 1.
        // Final contract address = CREATE = keccak256(0xd6 ++ 0x94 ++ proxyAddress ++ 0x01)[12:]
        // https://github.com/Vectorized/solady/blob/main/src/utils/CREATE3.sol
        return ICREATE3Factory(factoryAddress).getDeployed(getSalt(saltIndex));
    }

    function deploy(bytes memory creationCode, string memory saltIndex) public returns (address) {
        // the create3 factory deployer expected to be the same deploying UUPS proxies
        address factory = getCreate3FactoryAddress();
        return ICREATE3Factory(factory).deploy(getSalt(saltIndex), creationCode);
    }

    function deployUUPS(
        address implementation,
        bytes memory initData,
        string memory saltIndex
    ) public returns (address) {
        // creating a proxy UUPS
        bytes memory creationCode = type(ERC1967Proxy).creationCode;
        // the implementation contract in constructor and the initialization data
        // the initialization data its used to initialize the proxy based on \
        // implementation initialization method commonly `initialize`
        bytes memory initializeImplData = abi.encode(implementation, initData);
        bytes memory initCode = abi.encodePacked(creationCode, initializeImplData);
        // the create3 factory deployer expected to be the same deploying UUPS proxies
        address factory = getCreate3FactoryAddress();
        // `factory` holds the address of the CREATE3 factory, used for deploying UUPS proxies at
        // predictable addresses based on a specified `salt`. This ensures consistent and known
        // deployment addresses.

        // Within this `startBroadcast` block, all transactions and deployments are signed and sent
        // from the account set by the private key provided (e.g., `getAdminPK()`), meaning `msg.sender`
        // will be that external account, not the calling contract (`DeployBase` in this case).
        // This maintains `msg.sender` consistency across deployments, essential for permissions and
        // authentication.
        // https://book.getfoundry.sh/cheatcodes/start-broadcast

        // Why is this needed?
        // In test deployments, when scripts are used for deployments,
        // `msg.sender` can be modified due to transitions across contract calls.
        // For example: TestA -> Deploy Contract A -> Call Create3 -> Create Factory,
        // where `TestA` becomes the `msg.sender` in the entire call chain.
        // This inconsistency can lead to different addresses depending on the sender.
        // To maintain consistency and preserve the original sender across all contexts, we use this approach.
        // https://book.getfoundry.sh/cheatcodes/read-callers
        return ICREATE3Factory(factory).deploy(getSalt(saltIndex), initCode);
    }

    // Checks if the predicted address matches the expected address.
    function _checkExpectedAddress(address expected, string memory saltIndex) internal view {
        address predictedAddress = computeCreate3Address(saltIndex);
        require(expected == predictedAddress, "Invalid address mismatch");
    }

    function _logAddress(string memory index, address contractAddress) internal {
        string memory output = string.concat(index, "=", Strings.toHexString(contractAddress));
        vm.writeLine(".env", output);
    }
}
