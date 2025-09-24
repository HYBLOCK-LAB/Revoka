
-include .env


docs: auth ## Create HTML files for codelabs
	@cd ./session/week1 && claat export week1.md && cd ../../ && rm -rf ./html/week1/** && mv ./session/week1/html/** ./docs/week1/


help: ## Show help message
	@awk 'BEGIN {FS = ":.*?## "}; /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

%:
	@: