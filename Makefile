include .env
export

.DEFAULT_GOAL := all
network=amoy
report=lcov
stage=development

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
	@forge build

.PHONY: force-compile ## compile contracts
force-compile:
	@forge clean && forge build

# https://jestjs.io/docs/cli#--coverageboolean
.PHONY: test ## run tests
test:
	@forge test --gas-report --show-progress -vvv  

.PHONY: coverage ## run tests coverage report
coverage:
	@forge clean
	@forge coverage --report $(report)
	@npx lcov-badge2 -o ./.github/workflows/cov-badge.svg lcov.info

.PHONY: secreport ## generate a security analysis report using aderyn
secreport:
	@aderyn

.PHONY: sectest ## run secutiry tests using slither
sectest:
	@export PATH=$HOME/.local/bin:$PATH	
	@slither . 

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
	@forge script --chain $(network) script/$(script) --rpc-url $(network) --broadcast 

# forge verify-contract 0x21173483074a46c302c4252e04c76fA90e6DdA6C MMC --chain amoy
.PHONY: verify ## verify contract
verify: 
	@forge verify-contract $(address) $(contract) --api-key $(network) --chain $(network)


rebuild: clean
all: test lint

.PHONY: help  ## display this message
help:
	@grep -E \
		'^.PHONY: .*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ".PHONY: |## "}; {printf "\033[36m%-19s\033[0m %s\n", $$2, $$3}'