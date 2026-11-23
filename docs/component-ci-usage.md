# Component repository integration

Every component repository keeps a small caller workflow; build logic remains versioned here.

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  component:
    uses: acme/obs-gitops-pipelines/.github/workflows/reusable-component-ci.yml@v1
    with:
      runtime: go
      runtime-version: '1.24.x'
      lint-command: go vet ./...
      test-command: go test -race ./...
      image-name: obs-notification-router
      chart-path: charts/obs-notification-router
      component: notification-router
      publish: ${{ github.event_name == 'push' }}
    secrets:
      GITOPS_APP_ID: ${{ secrets.GITOPS_APP_ID }}
      GITOPS_APP_PRIVATE_KEY: ${{ secrets.GITOPS_APP_PRIVATE_KEY }}
```

For Node applications use `runtime: node`, a pinned Node version, `npm run lint`, and `npm test`. A multi-image repository invokes the reusable workflow once per independently versioned chart/image.

The GitHub App must have `Contents: write` and `Pull requests: write` only on `obs-gitops-pipelines`. Component workflows have no Kubernetes, Vault, or Argo CD credential.

## Infrastructure repository exception

`obs-platform-infra` has no runtime image or Helm chart, so manufacturing an empty artifact would weaken the contract. It calls `reusable-terraform-ci.yml`: fmt, validate, TFLint, Terraform tests, and plan always run; apply re-plans after a protected GitHub environment approval. Terraform Cloud provides provider credentials through workload identity and holds encrypted state.

```yaml
jobs:
  infrastructure:
    uses: acme/obs-gitops-pipelines/.github/workflows/reusable-terraform-ci.yml@v1
    with:
      workspace: obs-platform-prod
      working-directory: environments/prod
      apply: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
      github-environment: production-infrastructure
    secrets:
      TF_CLOUD_TOKEN: ${{ secrets.TF_CLOUD_TOKEN }}
```

## Service repository manifest check

```yaml
name: observability-manifest
on:
  pull_request:
    paths: [observability.yaml]
jobs:
  observability-manifest:
    uses: acme/obs-gitops-pipelines/.github/workflows/obs-manifest-lint.yml@v1
    with:
      manifest-path: observability.yaml
```

Run `GH_TOKEN=... ./scripts/configure-service-repository.sh acme/payments-api` once. It requires the `observability-manifest / validate-observability-manifest` check, one CODEOWNER approval, approval by someone other than the last pusher, resolved conversations, linear history, and blocks force-push/deletion. Auto-merge may be enabled on the PR, but GitHub merges only after all these controls pass.
