# Flux no mesmo Kind

Reaproveita `exemplos/dora/chart`, com uma release em `flux-demo`.
Argo continua gerenciando sua aplicação em `production`.

## Instalação

Depois do setup de `exemplos/dora/`, a partir da raiz do repositório:

```bash
./exemplos/flux/install.sh
kubectl --context kind-argo-dora-live apply -f exemplos/flux/source.yaml
kubectl --context kind-argo-dora-live apply -f exemplos/flux/sync.yaml
kubectl --context kind-argo-dora-live -n flux-system wait gitrepository/loja-flux --for=condition=Ready --timeout=120s
kubectl --context kind-argo-dora-live -n flux-system wait kustomization/loja-flux --for=condition=Ready --timeout=120s
kubectl --context kind-argo-dora-live -n flux-demo wait helmrelease/loja-flux --for=condition=Ready --timeout=180s
```

Para usar um fork, ajuste a URL em `source.yaml`. Os scripts aceitam
`CLUSTER_NAME`; ajuste o contexto nos comandos manuais se mudar o nome.

## Recursos

| Recurso | Responsabilidade |
| --- | --- |
| `GitRepository` | Buscar o Git e produzir um artefato |
| `Kustomization` do Flux | Reconciliar a pasta `apps/`, criando namespace e HelmRelease |
| `HelmRelease` | Instalar/atualizar a release usando o chart do mesmo Git |
| `HelmChart` | Recurso criado pelo controller para empacotar o chart |

O arquivo `apps/kustomization.yaml` configura o build do Kustomize. Ele tem
uma API diferente do recurso `Kustomization` do Flux em `sync.yaml`.
O sync deste exemplo confirma a aplicação do HelmRelease; a condição Ready
do HelmRelease informa o resultado da operação Helm.

```bash
kubectl --context kind-argo-dora-live -n flux-system get gitrepositories,kustomizations,helmcharts
kubectl --context kind-argo-dora-live -n flux-demo get helmreleases
helm --kube-context kind-argo-dora-live list -n flux-demo
helm --kube-context kind-argo-dora-live history loja-flux -n flux-demo
```

Em outro terminal:

```bash
kubectl --context kind-argo-dora-live -n flux-demo port-forward svc/loja 8082:8080
```

```bash
curl -i http://localhost:8082/
```

## Upgrade, falha e recuperação

Edite somente `apps/helmrelease.yaml`, dentro de `spec.values`.
Faça commit/push depois de cada alteração e espere os controllers reconciliarem.
Não é necessário alterar a versão do chart: `reconcileStrategy: Revision`
permite empacotar o chart quando a revisão do Git muda.

| Alteração | Resultado esperado |
| --- | --- |
| `version: flux-v2` | Upgrade bem-sucedido; HTTP 200 com flux-v2 |
| `version: flux-v3-bad`, `imageTag: nao-existe` | Upgrade falha; rollback para a release anterior |
| Restaurar `version: flux-v2` e `imageTag: 1.28.0-alpine` | Estado desejado válido; HelmRelease volta a Ready |
| `broken: true` | HelmRelease pode ficar Ready com checkout HTTP 503 |

O timeout da operação é 1 minuto. Não há retries de upgrade; a última falha
também é remediada por rollback. Após o rollback, o serviço pode estar atendendo
e o HelmRelease continuar Ready=False, porque a configuração desejada ainda
falhou. Corrija o Git para voltar a convergir.

```bash
kubectl --context kind-argo-dora-live -n flux-demo describe helmrelease loja-flux
helm --kube-context kind-argo-dora-live history loja-flux -n flux-demo
```

As anotações PreSync do chart pertencem ao Argo; `failSync` fica false neste
exemplo. Reabra o port-forward se o pod escolhido tiver sido substituído.
Restaure os valores iniciais ao terminar. A limpeza do Kind remove ambos os labs.

## Referências

- [Componentes do Flux](https://fluxcd.io/flux/components/)
- [HelmRelease e remediação](https://fluxcd.io/flux/components/helm/helmreleases/)
- [HelmChart e estratégia Revision](https://fluxcd.io/flux/components/source/helmcharts/)
