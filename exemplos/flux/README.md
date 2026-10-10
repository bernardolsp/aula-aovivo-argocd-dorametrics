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

## Dependências e health checks

`spec.dependsOn` permite aguardar outros recursos de reconciliação ficarem
Ready. Em uma `Kustomization`, as dependências são outras Kustomizations;
em um `HelmRelease`, são outros HelmReleases.

Exemplo de trechos para duas Kustomizations no mesmo namespace: `infra`
instala um controller e seus CRDs; `apps` aplica os recursos que usam esses CRDs.

```yaml
# Na Kustomization apps:
spec:
  dependsOn:
    - name: infra
```

```yaml
# Na Kustomization infra:
spec:
  wait: true
  timeout: 2m
```

A dependência precisa ter health checks adequados: sem eles, Ready pode
significar apenas que os manifests foram aplicados. `wait: true` verifica
todos os recursos reconciliados; `healthChecks` seleciona recursos específicos.
Quando wait é true, a lista healthChecks é ignorada. Evite dependências circulares.

Neste lab, uma opção seria acrescentar este trecho ao `spec` de `sync.yaml`:

```yaml
healthChecks:
  - apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    name: loja-flux
    namespace: flux-demo
timeout: 2m
```

Assim, a Kustomization também esperaria o HelmRelease ficar Ready. O exemplo
mantém as condições separadas para observar cada controller. Esses checks
também não detectam o checkout 503 com readiness 200.

## Flux bootstrap

`flux bootstrap github` instala os controllers, faz commit/push dos manifests
de instalação e configura a sincronização de uma pasta do Git. A partir daí,
o Flux reconcilia também sua própria instalação. O script deste lab instala
uma versão fixa; a source e o sync acompanham somente a pasta de aplicações.

Exemplo para outro Kind e um repositório de sua conta, usando a CLI do Flux:

```bash
flux bootstrap github \
  --context=kind-meu-cluster \
  --owner=SEU_USUARIO \
  --repository=flux-gitops \
  --branch=main \
  --path=clusters/meu-cluster \
  --personal
```

O comando requer acesso administrativo ao cluster e ao repositório, e um PAT
do GitHub (via GITHUB_TOKEN ou prompt). Por padrão, configura uma deploy key
SSH; com `--token-auth`, usa HTTPS e armazena o PAT em um Secret no cluster.
Se o repositório não existir, pode criá-lo. É uma alternativa de setup para
um novo ambiente; a demo atual continua usando o instalador simples.

## Referências

- [Componentes do Flux](https://fluxcd.io/flux/components/)
- [HelmRelease e remediação](https://fluxcd.io/flux/components/helm/helmreleases/)
- [HelmChart e estratégia Revision](https://fluxcd.io/flux/components/source/helmcharts/)
- [Kustomization: dependências e health checks](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- [Bootstrap no GitHub](https://fluxcd.io/flux/installation/bootstrap/github/)
