# 既存の8個のマニフェストをそのまま使い、**依存関係の完了を待ちながら一括構築するスクリプト**。

手順は、Namespace → Secret → PostgreSQL → Redmine → Ingressの順になっています。([GitHub][1])

* [bootstrap-rancher-desktop.sh](sandbox:/mnt/data/redmine-on-kubernetes-update/scripts/bootstrap-rancher-desktop.sh)
* [ドキュメント追記案](sandbox:/mnt/data/redmine-on-kubernetes-update/docs-bootstrap-rancher-desktop.md)

リポジトリでは、次の場所に配置する想定です。

```text
redmine-on-kubernetes/
├── manifests/
├── docs/
└── scripts/
    └── bootstrap-rancher-desktop.sh
```

実行方法です。

```bash
cd redmine-on-kubernetes

mkdir -p scripts
# ダウンロードしたファイルを scripts/ に配置

chmod +x scripts/bootstrap-rancher-desktop.sh
./scripts/bootstrap-rancher-desktop.sh
```

スクリプトは次を順番に確認します。

1. `kubectl` のcontextが `rancher-desktop`
2. Kubernetes NodeがReady
3. default StorageClassが存在
4. TraefikのIngressClassが存在
5. PostgreSQL StatefulSetがReady
6. Redmine DeploymentがReady
7. Ingress作成後、`http://redmine.localhost` が応答

単なる固定秒数の `sleep` ではなく、以下のようなKubernetes側の状態を待ちます。

```bash
kubectl wait --for=condition=Ready node --all

kubectl -n redmine-on-kubernetes rollout status \
  statefulset/postgres

kubectl -n redmine-on-kubernetes rollout status \
  deployment/redmine
```

既存マニフェスト上でもPostgreSQLは `StatefulSet/postgres`、Redmineは `Deployment/redmine` なので、それに合わせています。([GitHub][2])

途中で失敗した場合は、自動的に以下を表示します。

```text
Node状態
Pod / Service / PVC / Ingress状態
直近のEvent
PostgreSQLログ
Redmineログ
```

なお、このスクリプトは既存のマニフェストを変更せず、`kubectl apply` で利用します。そのため、初回構築だけでなく、途中失敗後の再実行にも対応しています。

Rancher Desktopをリセットした場合の用途に、かなり素直に合う形です。

[1]: https://github.com/YoshiyukiKono/redmine-on-kubernetes/blob/main/docs/rancher-desktop.md "redmine-on-kubernetes/docs/rancher-desktop.md at main · YoshiyukiKono/redmine-on-kubernetes · GitHub"
[2]: https://github.com/YoshiyukiKono/redmine-on-kubernetes/blob/main/manifests/12-postgres-statefulset.yaml "redmine-on-kubernetes/manifests/12-postgres-statefulset.yaml at main · YoshiyukiKono/redmine-on-kubernetes · GitHub"
