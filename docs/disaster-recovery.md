# Disaster recovery

| State | Authority and backup | RPO | Restore order |
|---|---|---:|---|
| Argo CD desired state | Protected GitHub repositories, immutable OCI chart/image retention, daily repository mirror to a second region | Commit-level | Rebuild cluster with `obs-platform-infra`, install Argo CD, register clusters, apply `projects/observability.yaml`, then the matching `bootstrap/*.yaml` |
| Argo CD runtime state | Daily Velero backup of `argocd` namespace including cluster-registration Secrets, repository credentials, RBAC ConfigMaps, and `argocd-secret`; encrypted object store with cross-region replication | 24h | Restore only after Argo CD CRDs/controller version match; rotate repository and cluster credentials after recovery |
| Vault secrets | Vault integrated-storage snapshots every 6h, immutable cross-region copy, quarterly restore exercise | 6h | Restore Vault before External Secrets; verify `observability-<env>` Kubernetes auth role/audience, then force ExternalSecret refresh |
| Grafana dashboards | Generated JSON and dashboard definitions in Git are authoritative; external PostgreSQL uses continuous WAL archive and daily snapshot | 5m DB PITR | Restore PostgreSQL to a consistent point, deploy Grafana, then let onboarding reconcile Git-generated dashboards; compare dashboard UID inventory |
| Prometheus/alert rule definitions | `obs-alert-rule-templates` and service manifests in Git; rendered rules are reconciled by onboarding | Commit-level | Restore Git/catalog, sync operator, verify PrometheusRule count and `promtool check rules` |
| Metrics history | Thanos object storage with versioning, object lock, lifecycle policy, and cross-region replication; bucket IAM/config is recreated by `obs-platform-infra` | Object replication lag | Recreate Query/Store/Compactor with the replicated bucket; run bucket verification before enabling Compactor writes |

Prometheus alert `for:` timers and in-memory rule evaluation state are intentionally not treated as durable authority. After a Prometheus restart they rebuild from current samples; active Alertmanager silences/state must be covered by the observability namespace backup. During restore, inhibit outbound page receivers until rule evaluation has completed at least two intervals, then run a synthetic alert end-to-end.

## Recovery acceptance checks

1. Argo CD reports every child Application `Synced/Healthy`; production Applications remain manual-sync.
2. External Secrets report `SecretSynced=True` without placing secret material in Git or logs.
3. Thanos can query a sample from before and after the disaster boundary.
4. Grafana dashboard UID count matches the catalog and OIDC login succeeds.
5. `Watchdog` reaches the notification router; a synthetic page reaches Slack/PagerDuty and resolves with the same dedup key.
6. Execute a failed canary in a non-production namespace and verify Rollouts returns traffic to the stable ReplicaSet.

