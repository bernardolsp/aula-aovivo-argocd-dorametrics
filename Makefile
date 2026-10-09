.PHONY: check render check-rules

check: render
	@for script in exemplos/dora/setup/*.sh exemplos/dora/gerar-metricas.sh exemplos/plugins/install.sh; do bash -n "$$script" || exit; done

render:
	helm template loja exemplos/dora/chart >/dev/null
	helm template loja exemplos/dora/chart --set broken=true >/dev/null
	helm template loja exemplos/dora/chart --set failSync=true >/dev/null

check-rules:
	docker run --rm --entrypoint promtool -v "$(CURDIR)/exemplos/dora/monitoring:/lab:ro" prom/prometheus:v3.5.0 check rules /lab/rules.yaml
