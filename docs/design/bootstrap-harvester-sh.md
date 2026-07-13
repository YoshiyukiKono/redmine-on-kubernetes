作成しました。

[Harvester版 `bootstrap-harvester.sh`](sandbox:/mnt/data/bootstrap-harvester.sh)

このスクリプトは、リポジトリの次の場所に置く想定です。

```text
redmine-on-kubernetes/
├── manifests/
└── scripts/
    └── bootstrap-harvester.sh
```

実行前に、ファイル冒頭のこの部分だけ確認・変更します。

```bash
EXPECTED_CONTEXT="REPLACE_WITH_YOUR_KUBERNETES_CONTEXT"
STORAGE_CLASS="longhorn"
INGRESS_CLASS="traefik"
REDMINE_HOST="redmine.example.local"
REDMINE_SCHEME="http"
```

特に重要なのは `EXPECTED_CONTEXT` です。

```bash
kubectl config get-contexts
kubectl config current-context
```

で対象クラスタのcontext名を確認し、その名前を設定します。スクリプトはcontextが一致しなければ停止するため、誤ってHarvester管理クラスタや別のKubernetesクラスタへ投入することを防ぎます。

実行は次のとおりです。

```bash
cd redmine-on-kubernetes

chmod +x scripts/bootstrap-harvester.sh
./scripts/bootstrap-harvester.sh
```

今回のHarvester版では、既存マニフェストを基本的に再利用しつつ、Harvester環境に依存しやすい次の2つだけスクリプト内で生成します。

* PostgreSQLとRedmineのPVC
* Ingress

そのため、StorageClassは明示的に設定されます。

```yaml
storageClassName: longhorn
```

Ingressも冒頭の設定から生成されます。

```yaml
ingressClassName: traefik
rules:
  - host: redmine.example.local
```

既存の構築手順が使っているNamespace、Secret、PostgreSQL、Redmine、Ingressという順序は維持しています。([GitHub][1])

注意点として、これは**Harvesterそのものへ直接Redmineを配置するスクリプトではなく、Harvester上で稼働するK3s/RKE2などのKubernetesクラスタへ配置するスクリプト**です。

また、`redmine.example.local` はブラウザを開くMacなどから名前解決できる必要があります。DNSがない場合は、一時的に `/etc/hosts` へIngressのIPとホスト名を登録します。

```text
192.168.x.x redmine.example.local
```

正常に終了すると、最後に次の情報が表示されます。

```text
URL:      http://redmine.example.local
Username: admin
Password: admin
```

初回ログイン後、Redmineから管理者パスワードの変更を求められます。

[1]: https://github.com/YoshiyukiKono/redmine-on-kubernetes/blob/main/docs/rancher-desktop.md "redmine-on-kubernetes/docs/rancher-desktop.md at main · YoshiyukiKono/redmine-on-kubernetes · GitHub"
