# Home SOC — convenience commands. Run `make help` for the list.
# Uses .RECIPEPREFIX so recipes work regardless of tabs-vs-spaces.
.RECIPEPREFIX := >
.DEFAULT_GOAL := help

DC := docker compose -f deploy/docker-compose.yml

.PHONY: up down restart health logs deploy-rules logtest destroy help

up: ## Bootstrap and start the SOC stack (certs, start, rules)
> bash scripts/setup.sh

down: ## Stop the stack (data volumes preserved)
> $(DC) down

restart: ## Restart all services
> $(DC) restart

health: ## Show container, indexer and agent health
> bash scripts/healthcheck.sh

logs: ## Tail logs from all services
> $(DC) logs -f --tail=100

deploy-rules: ## Deploy custom detection content into the manager (validate + reload)
> bash scripts/deploy-rules.sh

logtest: ## Open the interactive Wazuh rule tester
> $(DC) exec wazuh.manager /var/ossec/bin/wazuh-logtest

destroy: ## Stop the stack AND delete all data volumes (full lab reset)
> $(DC) down -v

help: ## Show this help
> @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
