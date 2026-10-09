# Argo CD — DORA Metrics

## Ambiente

Docker, Kind, kubectl e curl. Helm para `make check`.

```bash
git clone https://github.com/bernardolsp/aula-aovivo-argocd-dorametrics.git
cd aula-aovivo-argocd-dorametrics
./exemplos/dora/setup/install.sh
kubectl --context kind-argo-dora-live apply -f exemplos/dora/application.yaml
```

Sincronize `loja-prod` na UI do Argo CD.

Em terminais separados:

```bash
./exemplos/dora/setup/access.sh argocd      # https://localhost:8080
./exemplos/dora/setup/access.sh grafana     # http://localhost:3000
./exemplos/dora/setup/access.sh prometheus  # http://localhost:9090
./exemplos/dora/setup/access.sh pushgateway # http://localhost:9091
./exemplos/dora/setup/access.sh app         # http://localhost:8081
```

Argo CD: `admin`, senha exibida no setup. Grafana: `admin/admin`.
Dashboard: **LinuxTips → Argo CD e DORA — LinuxTips**.

## Aplicação

Edite `exemplos/dora/chart/values.yaml`, faça commit/push e sincronize pelo Argo.

| Valor | Resultado |
| --- | --- |
| `broken: false` | HTTP 200 |
| `broken: true` | HTTP 503; readiness continua retornando 200 |
| `failSync: true` | PreSync rejeita a mudança |

```bash
curl -i http://localhost:8081/
curl -i http://localhost:8081/ready
```

## Dados DORA

Com o port-forward do Pushgateway aberto:

```bash
./exemplos/dora/gerar-metricas.sh
```

Os arquivos de `dados/` são snapshots sintéticos de uma coorte de três entregas.
Os painéis inferiores usam esses dados; os superiores usam métricas reais do
Argo CD. Os arquivos não são calculados a partir dos syncs.

## CMP

```bash
./exemplos/plugins/install.sh
```

Sincronize `cmp-demo`. O sidecar executa `cat *.manifest` para produzir um ConfigMap.

## Verificação e limpeza

```bash
make check check-rules
./exemplos/dora/setup/cleanup.sh
```

`CLUSTER_NAME` altera o nome do cluster nos scripts. Para usar um fork,
ajuste `repoURL` nas duas Applications e `sourceRepos` no AppProject.

## Referências

- [Artigo de referência](https://oneuptime.com/blog/post/2026-02-26-argocd-dora-metrics-dashboard/view)
- [DORA](https://dora.dev/guides/dora-metrics/)
- [Métricas do Argo CD](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Config Management Plugins](https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/)
