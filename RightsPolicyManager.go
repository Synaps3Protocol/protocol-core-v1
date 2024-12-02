// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// RightsPolicyManagerMetaData contains all meta data concerning the RightsPolicyManager contract.
var RightsPolicyManagerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"rightsAgreement\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"rightsAuthorizer\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"RIGHTS_AGREEMENT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIRightsAccessAgreement\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"RIGHTS_AUTHORIZER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIRightsPolicyAuthorizer\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"UPGRADE_INTERFACE_VERSION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"authority\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getActivePolicy\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPolicies\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getPolicyAuthorizer\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"initialize\",\"inputs\":[{\"name\":\"accessManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isActivePolicy\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"assetId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"policyAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isConsumingScheduledOp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"registerPolicy\",\"inputs\":[{\"name\":\"proof\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"holder\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"policyAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setAuthority\",\"inputs\":[{\"name\":\"newAuthority\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AuthorityUpdated\",\"inputs\":[{\"name\":\"authority\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"PolicyRegistered\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"proof\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"attestationId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"policy\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"AccessManagedInvalidAuthority\",\"inputs\":[{\"name\":\"authority\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"AccessManagedRequiredDelay\",\"inputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"delay\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"type\":\"error\",\"name\":\"AccessManagedUnauthorized\",\"inputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"AddressEmptyCode\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC1967InvalidImplementation\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ERC1967NonPayable\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FailedCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidInitialization\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidNotRightsDelegated\",\"inputs\":[{\"name\":\"policy\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"holder\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"InvalidPolicyEnforcement\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"type\":\"error\",\"name\":\"InvalidUnauthorizedOperation\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"type\":\"error\",\"name\":\"NotInitializing\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UUPSUnauthorizedCallContext\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UUPSUnsupportedProxiableUUID\",\"inputs\":[{\"name\":\"slot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]",
	Bin: "0x60e03461016757601f611b6138819003918201601f19168301916001600160401b0383118484101761016b57808492604094855283398101031261016757610052602061004b8361017f565b920161017f565b90306080527ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a005460ff8160401c16610158576002600160401b03196001600160401b038216016100ef575b506001600160a01b0390811660a0521660c0526040516119cd90816101948239608051818181610d5d0152610eae015260a0518181816104d60152610e01015260c05181818161056f0152610c3b0152f35b6001600160401b0319166001600160401b039081177ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d290602090a15f61009d565b63f92ee8a960e01b5f5260045ffd5b5f80fd5b634e487b7160e01b5f52604160045260245ffd5b51906001600160a01b03821682036101675756fe6080806040526004361015610012575f80fd5b5f3560e01c908163338ebf21146112dd5750806341176077146112905780634f1ef28614610e255780634f622ffe14610dd557806352d1902d14610d365780637a9e5e4b14610c5f578063873bd57f14610c0f5780638ae2ba5914610c0f5780638fb3603714610b7c5780639f7434f414610447578063a5415d051461040d578063ad3cb1cc146103aa578063bf7e214f146103585763c4d66de8146100b6575f80fd5b34610354576020600319360112610354576100cf6113b0565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a005460ff8160401c16159167ffffffffffffffff82168015908161034c575b6001149081610342575b159081610339575b5061031157818360017fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000073ffffffffffffffffffffffffffffffffffffffff9516177ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00556102bc575b5061019261184b565b61019a61184b565b6101a261184b565b6101aa61184b565b6101b3816117a0565b6101bb61184b565b167fffffffffffffffffffffffff00000000000000000000000000000000000000007fb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa005416177fb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa005561022957005b7fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a0054167ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00557fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2602060405160018152a1005b7fffffffffffffffffffffffffffffffffffffffffffffff0000000000000000001668010000000000000001177ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00555f610189565b7ff92ee8a9000000000000000000000000000000000000000000000000000000005f5260045ffd5b9050155f610120565b303b159150610118565b84915061010e565b5f80fd5b34610354575f60031936011261035457602073ffffffffffffffffffffffffffffffffffffffff7ff3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a005416604051908152f35b34610354575f600319360112610354576104096040516103cb6040826113f6565b600581527f352e302e300000000000000000000000000000000000000000000000000000006020820152604051918291602083526020830190611471565b0390f35b3461035457606060031936011261035457602061043d61042b6113b0565b6104336113d3565b90602435906116c4565b6040519015158152f35b34610354576060600319360112610354576004356024359073ffffffffffffffffffffffffffffffffffffffff8216809203610354576104856113d3565b91604051927fe5f5677a0000000000000000000000000000000000000000000000000000000084528260048501528160248501525f846044818373ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000165af19384156109ad575f946109b8575b50604051917fca89d8b200000000000000000000000000000000000000000000000000000000835273ffffffffffffffffffffffffffffffffffffffff82169283600482015281602482015260208160448173ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000165afa9081156109ad575f91610973575b50156109445760405160208101917f497dc4ba000000000000000000000000000000000000000000000000000000008352602482015260406044820152610184810173ffffffffffffffffffffffffffffffffffffffff875116606483015273ffffffffffffffffffffffffffffffffffffffff602088015116608483015273ffffffffffffffffffffffffffffffffffffffff60408801511660a4830152606087015160c4830152608087015160e483015260a087015161010483015260c087015161012483015260e0870196875191610120610144850152825180915260206101a485019301905f5b81811061091857505050826107045f96946106d8889795610100899601517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9c84830301610164850152611471565b037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe081018352826113f6565b51925af191610711611695565b92156108955782518301926020818186019503126103545760208101519067ffffffffffffffff821161035457019383603f860112156103545760208501519361075a85611670565b9561076860405197886113f6565b8587526020870190602080839860051b8301010192831161035457604001905b8282106108855750505051908151925f5b8481106107e4578587604051918291602083019060208452518091526040830191905f5b8181106107cb575050500390f35b82518452859450602093840193909201916001016107bd565b806107f1600192896114b4565b5173ffffffffffffffffffffffffffffffffffffffff61081183886114b4565b51165f525f6020526108268460405f206118a2565b507f4c101be3810865ea0eacad6a85e5b5d8e0a720cbeb04812db1315974a30877b0606073ffffffffffffffffffffffffffffffffffffffff610869858a6114b4565b511692604051908882526020820152866040820152a201610799565b8151815260209182019101610788565b60846040517fafc7ba68000000000000000000000000000000000000000000000000000000008152602060048201526024808201527f4572726f7220647572696e6720706f6c69637920656e666f7263656d656e742060448201527f63616c6c000000000000000000000000000000000000000000000000000000006064820152fd5b825173ffffffffffffffffffffffffffffffffffffffff1685526020948501949092019160010161068a565b827f5fcd9007000000000000000000000000000000000000000000000000000000005f5260045260245260445ffd5b90506020813d6020116109a5575b8161098e602093836113f6565b810103126103545761099f90611688565b8661059f565b3d9150610981565b6040513d5f823e3d90fd5b9093503d805f833e6109ca81836113f6565b8101906020818303126103545780519067ffffffffffffffff8211610354570190610120828203126103545760405191610120830183811067ffffffffffffffff821117610b4f57604052610a1e8161164f565b8352610a2c6020820161164f565b6020840152610a3d6040820161164f565b6040840152606081015160608401526080810151608084015260a081015160a084015260c081015160c084015260e081015167ffffffffffffffff811161035457810182601f8201121561035457805190610a9782611670565b91610aa560405193846113f6565b80835260208084019160051b8301019185831161035457602001905b828210610b375750505060e08401526101008101519067ffffffffffffffff8211610354570181601f8201121561035457805190610afe82611437565b92610b0c60405194856113f6565b8284526020838301011161035457815f9260208093018386015e830101526101008201529284610506565b60208091610b448461164f565b815201910190610ac1565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b34610354575f600319360112610354577ff3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a005460a01c60ff1615610c075760207f8fb36037000000000000000000000000000000000000000000000000000000005b7fffffffff0000000000000000000000000000000000000000000000000000000060405191168152f35b60205f610bdd565b34610354575f60031936011261035457602060405173ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000168152f35b3461035457602060031936011261035457610c786113b0565b73ffffffffffffffffffffffffffffffffffffffff7ff3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a0054163303610d0a57803b15610cc857610cc6906117a0565b005b73ffffffffffffffffffffffffffffffffffffffff907fc2f31e5e000000000000000000000000000000000000000000000000000000005f521660045260245ffd5b7f068ca9d8000000000000000000000000000000000000000000000000000000005f523360045260245ffd5b34610354575f6003193601126103545773ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000163003610dad5760206040517f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc8152f35b7fe07c8dba000000000000000000000000000000000000000000000000000000005f5260045ffd5b34610354575f60031936011261035457602060405173ffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000168152f35b604060031936011261035457610e396113b0565b6024359067ffffffffffffffff8211610354573660238301121561035457816004013590610e6682611437565b91610e7460405193846113f6565b8083526020830193366024838301011161035457815f9260246020930187378401015273ffffffffffffffffffffffffffffffffffffffff7f00000000000000000000000000000000000000000000000000000000000000001680301490811561124e575b50610dad576044604073ffffffffffffffffffffffffffffffffffffffff7fb8e950798a2a06a6f5727a94041b193569f4f67d69a0de3cf866d93822e7fa0054168151928380927fd1f856ee0000000000000000000000000000000000000000000000000000000082525f60048301523360248301525afa9081156109ad575f91611203575b501561117f5773ffffffffffffffffffffffffffffffffffffffff8116926040517f52d1902d000000000000000000000000000000000000000000000000000000008152602081600481885afa5f918161114b575b50610fe557847f4c9c8ce3000000000000000000000000000000000000000000000000000000005f5260045260245ffd5b807f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc8692036111205750823b156110f557807fffffffffffffffffffffffff00000000000000000000000000000000000000007f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5416177f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc557fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b5f80a28251156110c3575f8091610cc6945190845af46110bd611695565b916118fe565b505050346110cd57005b7fb398979f000000000000000000000000000000000000000000000000000000005f5260045ffd5b7f4c9c8ce3000000000000000000000000000000000000000000000000000000005f5260045260245ffd5b7faa1d49a4000000000000000000000000000000000000000000000000000000005f5260045260245ffd5b9091506020813d602011611177575b81611167602093836113f6565b8101031261035457519086610fb4565b3d915061115a565b60846040517f6317e35f00000000000000000000000000000000000000000000000000000000815260206004820152602360248201527f4f6e6c792061646d696e2063616e20706572666f726d2074686973206163746960448201527f6f6e2e00000000000000000000000000000000000000000000000000000000006064820152fd5b90506040813d604011611246575b8161121e604093836113f6565b8101031261035457602061123182611688565b91015163ffffffff8116036103545784610f5f565b3d9150611211565b905073ffffffffffffffffffffffffffffffffffffffff7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5416141584610ed9565b3461035457604060031936011261035457604073ffffffffffffffffffffffffffffffffffffffff6112cc6112c36113b0565b602435906114f5565b835191151582529091166020820152f35b346103545760206003193601126103545773ffffffffffffffffffffffffffffffffffffffff61130b6113b0565b165f525f60205260405f20908154808252602082019081935f5260205f20905f5b81811061139a57505050816113429103826113f6565b604051918291602083019060208452518091526040830191905f5b81811061136b575050500390f35b825173ffffffffffffffffffffffffffffffffffffffff1684528594506020938401939092019160010161135d565b825484526020909301926001928301920161132c565b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361035457565b6044359073ffffffffffffffffffffffffffffffffffffffff8216820361035457565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff821117610b4f57604052565b67ffffffffffffffff8111610b4f57601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200190565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b80518210156114c85760209160051b010190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b73ffffffffffffffffffffffffffffffffffffffff81165f525f60205260405f2090604051808360208295549384815201905f5260205f20925f5b818110611636575050611545925003836113f6565b8151907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8201918211611609575b61159e73ffffffffffffffffffffffffffffffffffffffff61159584866114b4565b511685836116c4565b6115df5781156115d5577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff61159e92019150611573565b505050505f905f90565b5073ffffffffffffffffffffffffffffffffffffffff9250611600916114b4565b51169060019190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8454835260019485019487945060209093019201611530565b519073ffffffffffffffffffffffffffffffffffffffff8216820361035457565b67ffffffffffffffff8111610b4f5760051b60200190565b5190811515820361035457565b3d156116bf573d906116a682611437565b916116b460405193846113f6565b82523d5f602084013e565b606090565b909173ffffffffffffffffffffffffffffffffffffffff809116911691825f525f6020526117038260405f206001915f520160205260405f2054151590565b9283611710575b50505090565b602092935060449060405194859384927fac3e8fb0000000000000000000000000000000000000000000000000000000008452600484015260248301525afa9081156109ad575f91611766575b505f808061170a565b90506020813d602011611798575b81611781602093836113f6565b810103126103545761179290611688565b5f61175d565b3d9150611774565b602073ffffffffffffffffffffffffffffffffffffffff7f2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad9216807fffffffffffffffffffffffff00000000000000000000000000000000000000007ff3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a005416177ff3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a0055604051908152a1565b60ff7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a005460401c161561187a57565b7fd7e6bcf8000000000000000000000000000000000000000000000000000000005f5260045ffd5b5f8281526001820160205260409020546118f85780549068010000000000000000821015610b4f57600182018082558210156114c85782600192825f5260205f2001558054925f520160205260405f2055600190565b50505f90565b9061193b575080511561191357805190602001fd5b7fd6bda275000000000000000000000000000000000000000000000000000000005f5260045ffd5b8151158061198e575b61194c575090565b73ffffffffffffffffffffffffffffffffffffffff907f9996b315000000000000000000000000000000000000000000000000000000005f521660045260245ffd5b50803b1561194456fea26469706673582212204a20b217ffddda63a9ad005e1f3c7e3019c4e4e1fd8639eda4ad9fc00fda987964736f6c634300081a0033",
}

// RightsPolicyManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use RightsPolicyManagerMetaData.ABI instead.
var RightsPolicyManagerABI = RightsPolicyManagerMetaData.ABI

// RightsPolicyManagerBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use RightsPolicyManagerMetaData.Bin instead.
var RightsPolicyManagerBin = RightsPolicyManagerMetaData.Bin

// DeployRightsPolicyManager deploys a new Ethereum contract, binding an instance of RightsPolicyManager to it.
func DeployRightsPolicyManager(auth *bind.TransactOpts, backend bind.ContractBackend, rightsAgreement common.Address, rightsAuthorizer common.Address) (common.Address, *types.Transaction, *RightsPolicyManager, error) {
	parsed, err := RightsPolicyManagerMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(RightsPolicyManagerBin), backend, rightsAgreement, rightsAuthorizer)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &RightsPolicyManager{RightsPolicyManagerCaller: RightsPolicyManagerCaller{contract: contract}, RightsPolicyManagerTransactor: RightsPolicyManagerTransactor{contract: contract}, RightsPolicyManagerFilterer: RightsPolicyManagerFilterer{contract: contract}}, nil
}

// RightsPolicyManager is an auto generated Go binding around an Ethereum contract.
type RightsPolicyManager struct {
	RightsPolicyManagerCaller     // Read-only binding to the contract
	RightsPolicyManagerTransactor // Write-only binding to the contract
	RightsPolicyManagerFilterer   // Log filterer for contract events
}

// RightsPolicyManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type RightsPolicyManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RightsPolicyManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RightsPolicyManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RightsPolicyManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RightsPolicyManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RightsPolicyManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RightsPolicyManagerSession struct {
	Contract     *RightsPolicyManager // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// RightsPolicyManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RightsPolicyManagerCallerSession struct {
	Contract *RightsPolicyManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// RightsPolicyManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RightsPolicyManagerTransactorSession struct {
	Contract     *RightsPolicyManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// RightsPolicyManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type RightsPolicyManagerRaw struct {
	Contract *RightsPolicyManager // Generic contract binding to access the raw methods on
}

// RightsPolicyManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RightsPolicyManagerCallerRaw struct {
	Contract *RightsPolicyManagerCaller // Generic read-only contract binding to access the raw methods on
}

// RightsPolicyManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RightsPolicyManagerTransactorRaw struct {
	Contract *RightsPolicyManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRightsPolicyManager creates a new instance of RightsPolicyManager, bound to a specific deployed contract.
func NewRightsPolicyManager(address common.Address, backend bind.ContractBackend) (*RightsPolicyManager, error) {
	contract, err := bindRightsPolicyManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManager{RightsPolicyManagerCaller: RightsPolicyManagerCaller{contract: contract}, RightsPolicyManagerTransactor: RightsPolicyManagerTransactor{contract: contract}, RightsPolicyManagerFilterer: RightsPolicyManagerFilterer{contract: contract}}, nil
}

// NewRightsPolicyManagerCaller creates a new read-only instance of RightsPolicyManager, bound to a specific deployed contract.
func NewRightsPolicyManagerCaller(address common.Address, caller bind.ContractCaller) (*RightsPolicyManagerCaller, error) {
	contract, err := bindRightsPolicyManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerCaller{contract: contract}, nil
}

// NewRightsPolicyManagerTransactor creates a new write-only instance of RightsPolicyManager, bound to a specific deployed contract.
func NewRightsPolicyManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*RightsPolicyManagerTransactor, error) {
	contract, err := bindRightsPolicyManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerTransactor{contract: contract}, nil
}

// NewRightsPolicyManagerFilterer creates a new log filterer instance of RightsPolicyManager, bound to a specific deployed contract.
func NewRightsPolicyManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*RightsPolicyManagerFilterer, error) {
	contract, err := bindRightsPolicyManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerFilterer{contract: contract}, nil
}

// bindRightsPolicyManager binds a generic wrapper to an already deployed contract.
func bindRightsPolicyManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RightsPolicyManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RightsPolicyManager *RightsPolicyManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RightsPolicyManager.Contract.RightsPolicyManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RightsPolicyManager *RightsPolicyManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.RightsPolicyManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RightsPolicyManager *RightsPolicyManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.RightsPolicyManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RightsPolicyManager *RightsPolicyManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RightsPolicyManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RightsPolicyManager *RightsPolicyManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RightsPolicyManager *RightsPolicyManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.contract.Transact(opts, method, params...)
}

// RIGHTSAGREEMENT is a free data retrieval call binding the contract method 0x4f622ffe.
//
// Solidity: function RIGHTS_AGREEMENT() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCaller) RIGHTSAGREEMENT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "RIGHTS_AGREEMENT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RIGHTSAGREEMENT is a free data retrieval call binding the contract method 0x4f622ffe.
//
// Solidity: function RIGHTS_AGREEMENT() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerSession) RIGHTSAGREEMENT() (common.Address, error) {
	return _RightsPolicyManager.Contract.RIGHTSAGREEMENT(&_RightsPolicyManager.CallOpts)
}

// RIGHTSAGREEMENT is a free data retrieval call binding the contract method 0x4f622ffe.
//
// Solidity: function RIGHTS_AGREEMENT() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) RIGHTSAGREEMENT() (common.Address, error) {
	return _RightsPolicyManager.Contract.RIGHTSAGREEMENT(&_RightsPolicyManager.CallOpts)
}

// RIGHTSAUTHORIZER is a free data retrieval call binding the contract method 0x873bd57f.
//
// Solidity: function RIGHTS_AUTHORIZER() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCaller) RIGHTSAUTHORIZER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "RIGHTS_AUTHORIZER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RIGHTSAUTHORIZER is a free data retrieval call binding the contract method 0x873bd57f.
//
// Solidity: function RIGHTS_AUTHORIZER() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerSession) RIGHTSAUTHORIZER() (common.Address, error) {
	return _RightsPolicyManager.Contract.RIGHTSAUTHORIZER(&_RightsPolicyManager.CallOpts)
}

// RIGHTSAUTHORIZER is a free data retrieval call binding the contract method 0x873bd57f.
//
// Solidity: function RIGHTS_AUTHORIZER() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) RIGHTSAUTHORIZER() (common.Address, error) {
	return _RightsPolicyManager.Contract.RIGHTSAUTHORIZER(&_RightsPolicyManager.CallOpts)
}

// UPGRADEINTERFACEVERSION is a free data retrieval call binding the contract method 0xad3cb1cc.
//
// Solidity: function UPGRADE_INTERFACE_VERSION() view returns(string)
func (_RightsPolicyManager *RightsPolicyManagerCaller) UPGRADEINTERFACEVERSION(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "UPGRADE_INTERFACE_VERSION")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// UPGRADEINTERFACEVERSION is a free data retrieval call binding the contract method 0xad3cb1cc.
//
// Solidity: function UPGRADE_INTERFACE_VERSION() view returns(string)
func (_RightsPolicyManager *RightsPolicyManagerSession) UPGRADEINTERFACEVERSION() (string, error) {
	return _RightsPolicyManager.Contract.UPGRADEINTERFACEVERSION(&_RightsPolicyManager.CallOpts)
}

// UPGRADEINTERFACEVERSION is a free data retrieval call binding the contract method 0xad3cb1cc.
//
// Solidity: function UPGRADE_INTERFACE_VERSION() view returns(string)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) UPGRADEINTERFACEVERSION() (string, error) {
	return _RightsPolicyManager.Contract.UPGRADEINTERFACEVERSION(&_RightsPolicyManager.CallOpts)
}

// Authority is a free data retrieval call binding the contract method 0xbf7e214f.
//
// Solidity: function authority() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCaller) Authority(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "authority")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Authority is a free data retrieval call binding the contract method 0xbf7e214f.
//
// Solidity: function authority() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerSession) Authority() (common.Address, error) {
	return _RightsPolicyManager.Contract.Authority(&_RightsPolicyManager.CallOpts)
}

// Authority is a free data retrieval call binding the contract method 0xbf7e214f.
//
// Solidity: function authority() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) Authority() (common.Address, error) {
	return _RightsPolicyManager.Contract.Authority(&_RightsPolicyManager.CallOpts)
}

// GetActivePolicy is a free data retrieval call binding the contract method 0x41176077.
//
// Solidity: function getActivePolicy(address account, uint256 assetId) view returns(bool, address)
func (_RightsPolicyManager *RightsPolicyManagerCaller) GetActivePolicy(opts *bind.CallOpts, account common.Address, assetId *big.Int) (bool, common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "getActivePolicy", account, assetId)

	if err != nil {
		return *new(bool), *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)
	out1 := *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return out0, out1, err

}

// GetActivePolicy is a free data retrieval call binding the contract method 0x41176077.
//
// Solidity: function getActivePolicy(address account, uint256 assetId) view returns(bool, address)
func (_RightsPolicyManager *RightsPolicyManagerSession) GetActivePolicy(account common.Address, assetId *big.Int) (bool, common.Address, error) {
	return _RightsPolicyManager.Contract.GetActivePolicy(&_RightsPolicyManager.CallOpts, account, assetId)
}

// GetActivePolicy is a free data retrieval call binding the contract method 0x41176077.
//
// Solidity: function getActivePolicy(address account, uint256 assetId) view returns(bool, address)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) GetActivePolicy(account common.Address, assetId *big.Int) (bool, common.Address, error) {
	return _RightsPolicyManager.Contract.GetActivePolicy(&_RightsPolicyManager.CallOpts, account, assetId)
}

// GetPolicies is a free data retrieval call binding the contract method 0x338ebf21.
//
// Solidity: function getPolicies(address account) view returns(address[])
func (_RightsPolicyManager *RightsPolicyManagerCaller) GetPolicies(opts *bind.CallOpts, account common.Address) ([]common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "getPolicies", account)

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetPolicies is a free data retrieval call binding the contract method 0x338ebf21.
//
// Solidity: function getPolicies(address account) view returns(address[])
func (_RightsPolicyManager *RightsPolicyManagerSession) GetPolicies(account common.Address) ([]common.Address, error) {
	return _RightsPolicyManager.Contract.GetPolicies(&_RightsPolicyManager.CallOpts, account)
}

// GetPolicies is a free data retrieval call binding the contract method 0x338ebf21.
//
// Solidity: function getPolicies(address account) view returns(address[])
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) GetPolicies(account common.Address) ([]common.Address, error) {
	return _RightsPolicyManager.Contract.GetPolicies(&_RightsPolicyManager.CallOpts, account)
}

// GetPolicyAuthorizer is a free data retrieval call binding the contract method 0x8ae2ba59.
//
// Solidity: function getPolicyAuthorizer() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCaller) GetPolicyAuthorizer(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "getPolicyAuthorizer")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetPolicyAuthorizer is a free data retrieval call binding the contract method 0x8ae2ba59.
//
// Solidity: function getPolicyAuthorizer() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerSession) GetPolicyAuthorizer() (common.Address, error) {
	return _RightsPolicyManager.Contract.GetPolicyAuthorizer(&_RightsPolicyManager.CallOpts)
}

// GetPolicyAuthorizer is a free data retrieval call binding the contract method 0x8ae2ba59.
//
// Solidity: function getPolicyAuthorizer() view returns(address)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) GetPolicyAuthorizer() (common.Address, error) {
	return _RightsPolicyManager.Contract.GetPolicyAuthorizer(&_RightsPolicyManager.CallOpts)
}

// IsActivePolicy is a free data retrieval call binding the contract method 0xa5415d05.
//
// Solidity: function isActivePolicy(address account, uint256 assetId, address policyAddress) view returns(bool)
func (_RightsPolicyManager *RightsPolicyManagerCaller) IsActivePolicy(opts *bind.CallOpts, account common.Address, assetId *big.Int, policyAddress common.Address) (bool, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "isActivePolicy", account, assetId, policyAddress)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsActivePolicy is a free data retrieval call binding the contract method 0xa5415d05.
//
// Solidity: function isActivePolicy(address account, uint256 assetId, address policyAddress) view returns(bool)
func (_RightsPolicyManager *RightsPolicyManagerSession) IsActivePolicy(account common.Address, assetId *big.Int, policyAddress common.Address) (bool, error) {
	return _RightsPolicyManager.Contract.IsActivePolicy(&_RightsPolicyManager.CallOpts, account, assetId, policyAddress)
}

// IsActivePolicy is a free data retrieval call binding the contract method 0xa5415d05.
//
// Solidity: function isActivePolicy(address account, uint256 assetId, address policyAddress) view returns(bool)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) IsActivePolicy(account common.Address, assetId *big.Int, policyAddress common.Address) (bool, error) {
	return _RightsPolicyManager.Contract.IsActivePolicy(&_RightsPolicyManager.CallOpts, account, assetId, policyAddress)
}

// IsConsumingScheduledOp is a free data retrieval call binding the contract method 0x8fb36037.
//
// Solidity: function isConsumingScheduledOp() view returns(bytes4)
func (_RightsPolicyManager *RightsPolicyManagerCaller) IsConsumingScheduledOp(opts *bind.CallOpts) ([4]byte, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "isConsumingScheduledOp")

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsConsumingScheduledOp is a free data retrieval call binding the contract method 0x8fb36037.
//
// Solidity: function isConsumingScheduledOp() view returns(bytes4)
func (_RightsPolicyManager *RightsPolicyManagerSession) IsConsumingScheduledOp() ([4]byte, error) {
	return _RightsPolicyManager.Contract.IsConsumingScheduledOp(&_RightsPolicyManager.CallOpts)
}

// IsConsumingScheduledOp is a free data retrieval call binding the contract method 0x8fb36037.
//
// Solidity: function isConsumingScheduledOp() view returns(bytes4)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) IsConsumingScheduledOp() ([4]byte, error) {
	return _RightsPolicyManager.Contract.IsConsumingScheduledOp(&_RightsPolicyManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RightsPolicyManager *RightsPolicyManagerCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _RightsPolicyManager.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RightsPolicyManager *RightsPolicyManagerSession) ProxiableUUID() ([32]byte, error) {
	return _RightsPolicyManager.Contract.ProxiableUUID(&_RightsPolicyManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RightsPolicyManager *RightsPolicyManagerCallerSession) ProxiableUUID() ([32]byte, error) {
	return _RightsPolicyManager.Contract.ProxiableUUID(&_RightsPolicyManager.CallOpts)
}

// Initialize is a paid mutator transaction binding the contract method 0xc4d66de8.
//
// Solidity: function initialize(address accessManager) returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactor) Initialize(opts *bind.TransactOpts, accessManager common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.contract.Transact(opts, "initialize", accessManager)
}

// Initialize is a paid mutator transaction binding the contract method 0xc4d66de8.
//
// Solidity: function initialize(address accessManager) returns()
func (_RightsPolicyManager *RightsPolicyManagerSession) Initialize(accessManager common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.Initialize(&_RightsPolicyManager.TransactOpts, accessManager)
}

// Initialize is a paid mutator transaction binding the contract method 0xc4d66de8.
//
// Solidity: function initialize(address accessManager) returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactorSession) Initialize(accessManager common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.Initialize(&_RightsPolicyManager.TransactOpts, accessManager)
}

// RegisterPolicy is a paid mutator transaction binding the contract method 0x9f7434f4.
//
// Solidity: function registerPolicy(uint256 proof, address holder, address policyAddress) returns(uint256[])
func (_RightsPolicyManager *RightsPolicyManagerTransactor) RegisterPolicy(opts *bind.TransactOpts, proof *big.Int, holder common.Address, policyAddress common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.contract.Transact(opts, "registerPolicy", proof, holder, policyAddress)
}

// RegisterPolicy is a paid mutator transaction binding the contract method 0x9f7434f4.
//
// Solidity: function registerPolicy(uint256 proof, address holder, address policyAddress) returns(uint256[])
func (_RightsPolicyManager *RightsPolicyManagerSession) RegisterPolicy(proof *big.Int, holder common.Address, policyAddress common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.RegisterPolicy(&_RightsPolicyManager.TransactOpts, proof, holder, policyAddress)
}

// RegisterPolicy is a paid mutator transaction binding the contract method 0x9f7434f4.
//
// Solidity: function registerPolicy(uint256 proof, address holder, address policyAddress) returns(uint256[])
func (_RightsPolicyManager *RightsPolicyManagerTransactorSession) RegisterPolicy(proof *big.Int, holder common.Address, policyAddress common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.RegisterPolicy(&_RightsPolicyManager.TransactOpts, proof, holder, policyAddress)
}

// SetAuthority is a paid mutator transaction binding the contract method 0x7a9e5e4b.
//
// Solidity: function setAuthority(address newAuthority) returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactor) SetAuthority(opts *bind.TransactOpts, newAuthority common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.contract.Transact(opts, "setAuthority", newAuthority)
}

// SetAuthority is a paid mutator transaction binding the contract method 0x7a9e5e4b.
//
// Solidity: function setAuthority(address newAuthority) returns()
func (_RightsPolicyManager *RightsPolicyManagerSession) SetAuthority(newAuthority common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.SetAuthority(&_RightsPolicyManager.TransactOpts, newAuthority)
}

// SetAuthority is a paid mutator transaction binding the contract method 0x7a9e5e4b.
//
// Solidity: function setAuthority(address newAuthority) returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactorSession) SetAuthority(newAuthority common.Address) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.SetAuthority(&_RightsPolicyManager.TransactOpts, newAuthority)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RightsPolicyManager.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RightsPolicyManager *RightsPolicyManagerSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.UpgradeToAndCall(&_RightsPolicyManager.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RightsPolicyManager *RightsPolicyManagerTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RightsPolicyManager.Contract.UpgradeToAndCall(&_RightsPolicyManager.TransactOpts, newImplementation, data)
}

// RightsPolicyManagerAuthorityUpdatedIterator is returned from FilterAuthorityUpdated and is used to iterate over the raw logs and unpacked data for AuthorityUpdated events raised by the RightsPolicyManager contract.
type RightsPolicyManagerAuthorityUpdatedIterator struct {
	Event *RightsPolicyManagerAuthorityUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RightsPolicyManagerAuthorityUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RightsPolicyManagerAuthorityUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RightsPolicyManagerAuthorityUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RightsPolicyManagerAuthorityUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RightsPolicyManagerAuthorityUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RightsPolicyManagerAuthorityUpdated represents a AuthorityUpdated event raised by the RightsPolicyManager contract.
type RightsPolicyManagerAuthorityUpdated struct {
	Authority common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterAuthorityUpdated is a free log retrieval operation binding the contract event 0x2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad.
//
// Solidity: event AuthorityUpdated(address authority)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) FilterAuthorityUpdated(opts *bind.FilterOpts) (*RightsPolicyManagerAuthorityUpdatedIterator, error) {

	logs, sub, err := _RightsPolicyManager.contract.FilterLogs(opts, "AuthorityUpdated")
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerAuthorityUpdatedIterator{contract: _RightsPolicyManager.contract, event: "AuthorityUpdated", logs: logs, sub: sub}, nil
}

// WatchAuthorityUpdated is a free log subscription operation binding the contract event 0x2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad.
//
// Solidity: event AuthorityUpdated(address authority)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) WatchAuthorityUpdated(opts *bind.WatchOpts, sink chan<- *RightsPolicyManagerAuthorityUpdated) (event.Subscription, error) {

	logs, sub, err := _RightsPolicyManager.contract.WatchLogs(opts, "AuthorityUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RightsPolicyManagerAuthorityUpdated)
				if err := _RightsPolicyManager.contract.UnpackLog(event, "AuthorityUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAuthorityUpdated is a log parse operation binding the contract event 0x2f658b440c35314f52658ea8a740e05b284cdc84dc9ae01e891f21b8933e7cad.
//
// Solidity: event AuthorityUpdated(address authority)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) ParseAuthorityUpdated(log types.Log) (*RightsPolicyManagerAuthorityUpdated, error) {
	event := new(RightsPolicyManagerAuthorityUpdated)
	if err := _RightsPolicyManager.contract.UnpackLog(event, "AuthorityUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RightsPolicyManagerInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the RightsPolicyManager contract.
type RightsPolicyManagerInitializedIterator struct {
	Event *RightsPolicyManagerInitialized // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RightsPolicyManagerInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RightsPolicyManagerInitialized)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RightsPolicyManagerInitialized)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RightsPolicyManagerInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RightsPolicyManagerInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RightsPolicyManagerInitialized represents a Initialized event raised by the RightsPolicyManager contract.
type RightsPolicyManagerInitialized struct {
	Version uint64
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2.
//
// Solidity: event Initialized(uint64 version)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) FilterInitialized(opts *bind.FilterOpts) (*RightsPolicyManagerInitializedIterator, error) {

	logs, sub, err := _RightsPolicyManager.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerInitializedIterator{contract: _RightsPolicyManager.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2.
//
// Solidity: event Initialized(uint64 version)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *RightsPolicyManagerInitialized) (event.Subscription, error) {

	logs, sub, err := _RightsPolicyManager.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RightsPolicyManagerInitialized)
				if err := _RightsPolicyManager.contract.UnpackLog(event, "Initialized", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseInitialized is a log parse operation binding the contract event 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2.
//
// Solidity: event Initialized(uint64 version)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) ParseInitialized(log types.Log) (*RightsPolicyManagerInitialized, error) {
	event := new(RightsPolicyManagerInitialized)
	if err := _RightsPolicyManager.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RightsPolicyManagerPolicyRegisteredIterator is returned from FilterPolicyRegistered and is used to iterate over the raw logs and unpacked data for PolicyRegistered events raised by the RightsPolicyManager contract.
type RightsPolicyManagerPolicyRegisteredIterator struct {
	Event *RightsPolicyManagerPolicyRegistered // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RightsPolicyManagerPolicyRegisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RightsPolicyManagerPolicyRegistered)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RightsPolicyManagerPolicyRegistered)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RightsPolicyManagerPolicyRegisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RightsPolicyManagerPolicyRegisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RightsPolicyManagerPolicyRegistered represents a PolicyRegistered event raised by the RightsPolicyManager contract.
type RightsPolicyManagerPolicyRegistered struct {
	Account       common.Address
	Proof         *big.Int
	AttestationId *big.Int
	Policy        common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterPolicyRegistered is a free log retrieval operation binding the contract event 0x4c101be3810865ea0eacad6a85e5b5d8e0a720cbeb04812db1315974a30877b0.
//
// Solidity: event PolicyRegistered(address indexed account, uint256 proof, uint256 attestationId, address policy)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) FilterPolicyRegistered(opts *bind.FilterOpts, account []common.Address) (*RightsPolicyManagerPolicyRegisteredIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RightsPolicyManager.contract.FilterLogs(opts, "PolicyRegistered", accountRule)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerPolicyRegisteredIterator{contract: _RightsPolicyManager.contract, event: "PolicyRegistered", logs: logs, sub: sub}, nil
}

// WatchPolicyRegistered is a free log subscription operation binding the contract event 0x4c101be3810865ea0eacad6a85e5b5d8e0a720cbeb04812db1315974a30877b0.
//
// Solidity: event PolicyRegistered(address indexed account, uint256 proof, uint256 attestationId, address policy)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) WatchPolicyRegistered(opts *bind.WatchOpts, sink chan<- *RightsPolicyManagerPolicyRegistered, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _RightsPolicyManager.contract.WatchLogs(opts, "PolicyRegistered", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RightsPolicyManagerPolicyRegistered)
				if err := _RightsPolicyManager.contract.UnpackLog(event, "PolicyRegistered", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParsePolicyRegistered is a log parse operation binding the contract event 0x4c101be3810865ea0eacad6a85e5b5d8e0a720cbeb04812db1315974a30877b0.
//
// Solidity: event PolicyRegistered(address indexed account, uint256 proof, uint256 attestationId, address policy)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) ParsePolicyRegistered(log types.Log) (*RightsPolicyManagerPolicyRegistered, error) {
	event := new(RightsPolicyManagerPolicyRegistered)
	if err := _RightsPolicyManager.contract.UnpackLog(event, "PolicyRegistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RightsPolicyManagerUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the RightsPolicyManager contract.
type RightsPolicyManagerUpgradedIterator struct {
	Event *RightsPolicyManagerUpgraded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *RightsPolicyManagerUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RightsPolicyManagerUpgraded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(RightsPolicyManagerUpgraded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *RightsPolicyManagerUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RightsPolicyManagerUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RightsPolicyManagerUpgraded represents a Upgraded event raised by the RightsPolicyManager contract.
type RightsPolicyManagerUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*RightsPolicyManagerUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _RightsPolicyManager.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &RightsPolicyManagerUpgradedIterator{contract: _RightsPolicyManager.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *RightsPolicyManagerUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _RightsPolicyManager.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RightsPolicyManagerUpgraded)
				if err := _RightsPolicyManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUpgraded is a log parse operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_RightsPolicyManager *RightsPolicyManagerFilterer) ParseUpgraded(log types.Log) (*RightsPolicyManagerUpgraded, error) {
	event := new(RightsPolicyManagerUpgraded)
	if err := _RightsPolicyManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
