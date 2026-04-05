SHELL := /usr/bin/env bash

.PHONY: help init validate validate-ci up down restart ps logs pull

help:
	@echo "Available targets:"
	@echo "  make init         Create .env from .env.example if needed"
	@echo "  make validate     Validate local compose configuration"
	@echo "  make validate-ci  Run extended validation used by CI"
	@echo "  make up           Start the stack"
	@echo "  make down         Stop the stack"
	@echo "  make restart      Restart the stack"
	@echo "  make ps           Show container status"
	@echo "  make logs         Follow service logs"
	@echo "  make pull         Update the repo on the server"

init:
	@bash scripts/init.sh

validate:
	@bash scripts/validate.sh

validate-ci:
	@bash scripts/validate-ci.sh

up:
	@bash scripts/up.sh

down:
	@bash scripts/down.sh

restart: down up

ps:
	@docker compose ps

logs:
	@docker compose logs -f --tail=100

pull:
	@git pull --ff-only

