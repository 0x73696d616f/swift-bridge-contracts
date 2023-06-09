-include .env

# Deploy the contract to remote network and verify the code
deploy-network :;
	@export FOUNDRY_PROFILE=deploy && \
	forge script script/Deploy.s.sol:DeployScript -f ${network} --broadcast --verify --delay 20 --retries 10 -vvvv && \
	export FOUNDRY_PROFILE=default

# Deploy the contract to remote network and verify the code
deploy-anvil :;
	@export FOUNDRY_PROFILE=deploy && \
	forge script script/Deploy.s.sol:DeployScript -f http://127.0.0.1:8545/ --broadcast --delay 20 --retries 10 -vvvv && \
	export FOUNDRY_PROFILE=default
	
# Generates the docs to ./docs folder
docs :; 
	forge doc
