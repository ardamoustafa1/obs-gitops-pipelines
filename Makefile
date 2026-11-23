.PHONY: validate render
validate:
	./scripts/validate.sh
render:
	helm template platform-config charts/platform-config --set environment=dev

