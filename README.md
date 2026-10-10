# Argo CD — métricas e comparação com Flux

Kind, Argo CD, Nginx, Prometheus e Grafana. As métricas vêm do Argo CD;
o HTTP da aplicação permite comparar o estado do controller com o serviço.

## Ambiente

Docker, Kind, kubectl, Git e curl. Helm para `make check`.

```bash
git clone https://github.com/bernardolsp/aula-aovivo-argocd-dorametrics.git
cd aula-aovivo-argocd-dorametrics
./exemplos/dora/setup/install.sh
kubectl --context kind-argo-dora-live apply -f exemplos/dora/application.yaml
```

Sincronize `loja-prod` na UI. Em terminais separados:

```bash
./exemplos/dora/setup/access.sh argocd      # https://localhost:8080
./exemplos/dora/setup/access.sh grafana     # http://localhost:3000
./exemplos/dora/setup/access.sh prometheus  # http://localhost:9090
./exemplos/dora/setup/access.sh app         # http://localhost:8081
```

Argo: `admin`, senha exibida no setup. Grafana: `admin/admin`.
Dashboard: **LinuxTips → Argo CD — Métricas de operação**.

## Cenários

Edite `exemplos/dora/chart/values.yaml`. Mude um cenário por vez, faça commit/push
e Refresh/Sync no Argo. Para usar seu fork, ajuste `repoURL` e `sourceRepos`
em `application.yaml`.

| Cenário | Valores | O que observar |
| --- | --- | --- |
| Sucesso | valores iniciais | Healthy e HTTP 200 |
| Falha do checkout | `broken: true` | Sync Succeeded, Healthy e HTTP 503 |
| Rejeição antes do deploy | `failSync: true` | Sync Failed, Healthy; versão anterior continua atendendo |
| Falha do rollout | `imageTag: nao-existe` | Sync Succeeded, Progressing → Degraded; pod novo não inicia e o antigo continua atendendo |
| Recuperação | restaurar valores iniciais | Healthy e HTTP 200 |
| Repetição | Sync do mesmo commit | contador aumenta sem uma nova versão |

Valores iniciais:

```yaml
version: v1
imageTag: 1.28.0-alpine
broken: false
failSync: false
```

O Deployment usa RollingUpdate e prazo de progresso de 30s para a demo.
Espere o Argo observar a mudança de health; isso pode levar mais de 30s.
Após o PreSync falhar, restaure os valores pelo Git e remova o Job retido:

```bash
kubectl --context kind-argo-dora-live -n production delete job loja-validation
```

Compare as respostas:

```bash
curl -i http://localhost:8081/
curl -i http://localhost:8081/ready
```

Reabra o port-forward da aplicação se o pod escolhido tiver sido substituído.

## Métricas

- `argocd_app_sync_total`: operações de sync, inclusive repetições.
- `argocd_app_reconcile_*`: duração da reconciliação, agregada por namespace/destino nesta versão.
- `argocd_app_info`: health e sync status da Application.

O dashboard mostra contadores, falhas de sync, p95 de reconciliação, histórico
de estados e uma estimativa de tempo observado fora de Healthy em 5 minutos.
Essa estimativa soma amostras 0/1 de uma regra avaliada a cada 5s e multiplica
por 5. Inclui Progressing durante rollouts e falhas sem impacto no serviço.
Confira `up{job="argocd"}` antes de interpretar o estado.

Esse tempo acumulado **não é MTTR**: não separa incidentes nem calcula a média
das recuperações. Um checkout com 503 pode permanecer Healthy durante toda a
falha. Medir recuperação do serviço exige um sinal de impacto, início/fim e,
para DORA, relação com a entrega. Lacunas de coleta e atrasos do Argo também
limitam a estimativa.

## Verificação e limpeza

```bash
make check check-rules
./exemplos/dora/setup/cleanup.sh
```

`CLUSTER_NAME` altera o nome do cluster nos scripts.

## Flux

O [exemplo de Flux](exemplos/flux/README.md) usa o mesmo Kind e chart, com
`GitRepository`, `Kustomization` e `HelmRelease`. A aplicação fica em `flux-demo`.
Inclui upgrade, rollback após falha e recuperação pelo Git.

## Referências

- [Métricas do Argo CD](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Funções PromQL](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [Definições DORA](https://dora.dev/guides/dora-metrics/)
