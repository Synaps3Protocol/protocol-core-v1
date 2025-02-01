include .env
export

.DEFAULT_GOAL := all
package=types
network=polygon-amoy
report=lcov
stage=development
file=out/${contract}.sol/${contract}

# https://github.com/crytic/slither?tab=readme-ov-file#detectors
# https://book.getfoundry.sh/getting-started/installation
# https://github.com/Cyfrin/aderyn?tab=readme-ov-file
.PHONY: bootstrap ## setup initial development environment
bootstrap: install
	@npx husky install
	@npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'

.PHONY: clean ## clean installation and dist files
clean:
	@rm -rf cache
	@rm -rf artifacts
	@rm -rf node_modules
	@rm -rf cache_forge
	@npm cache clean --force
	@forge clean

.PHONY: forge-clean ## clean forge
forge-clean:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

.PHONY: forge-update ## upgrade forge
forge-update:
	@foundryup
	@forge update

.PHONY: compile ## compile contracts
compile:
	@forge build --extra-output-files bin abi

# https://geth.ethereum.org/docs/tools/abigen
# https://geth.ethereum.org/docs/getting-started/installing-geth
# eg:
# abigen --abi out/RightsPolicyManager.sol/RightsPolicyManager.abi.json --bin out/RightsPolicyManager.sol/RightsPolicyManager.bin /
# --pkg synapse --type RightsPolicyManager --out RightsPolicyManager.go
.PHONY: generate ## generate contract using abigen
generate:
	@abigen --abi ${file}.abi.json --bin ${file}.bin --pkg contracts --type ${contract} --out ${contract}.go
	@forge build --extra-output-files bin

.PHONY: force-compile ## compile contracts
force-compile:
	@forge clean && forge build

.PHONY: test ## run tests
test:
	@CI=true && forge test --show-progress --gas-report -vvv  --fail-fast 

.PHONY: coverage ## run tests coverage report
coverage:
	@forge clean
	@forge coverage --report $(report) --ir-minimum
	@npx lcov-badge2 -o ./.github/workflows/cov-badge.svg lcov.info

.PHONY: secreport ## generate a security analysis report using aderyn--verbose
secreport:
	@aderyn

.PHONY: sectest ## run secutiry tests using slither
sectest:
	@export PATH=$HOME/.local/bin:$PATH	
	@slither . --print human-summary

.PHONY: format ## auto-format solidity source files
format:
	@npx prettier --write contracts

.PHONY: lint ## lint standard  solidity
lint: 
	@npx solhint 'contracts/**/*.sol'

.PHONE: release ## generate a new release version
release:
	@npx semantic-release

.PHONY: syncenv ## pull environments to dotenv vault
syncenv: 
	@npx dotenv-vault@latest pull $(stage) -y

.PHONY: pushenv ## push environments to dotenv vault
pushenv: 
	@npx dotenv-vault@latest push $(stage) -y

.PHONY: keysenv ## get dotenv vault stage keys
keysenv: 
	@npx dotenv-vault@latest keys

.PHONY: deploy ## deploy contract
deploy: 
	@forge script --chain $(network) script/$(script) --rpc-url $(network) --broadcast --verify --private-key ${PRIVATE_KEY}

.PHONY: publish-package ## publish npm package
publish-package: 
	@cp -r contracts/ packages/$(package)
	@npm publish ./packages/$(package) --access public
	@rm -rf packages/$(package)/contracts

# forge verify-contract 0x21173483074a46c302c4252e04c76fA90e6DdA6C MMC --chain amoy
.PHONY: verify ## verify contract
verify: 
	@forge verify-contract $(address) $(contract) --api-key $(network) --chain $(network) --flatten

rebuild: clean
all: test lint

.PHONY: help  ## display this message
help:
	@grep -E \
		'^.PHONY: .*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ".PHONY: |## "}; {printf "\033[36m%-19s\033[0m %s\n", $$2, $$3}'