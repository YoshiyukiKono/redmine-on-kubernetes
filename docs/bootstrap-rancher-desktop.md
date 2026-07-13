# Rancher Desktopでの一括構築

リポジトリのルートで次を実行します。

```bash
chmod +x scripts/bootstrap-rancher-desktop.sh
./scripts/bootstrap-rancher-desktop.sh
```

スクリプトは、次の完了を確認しながら順番に処理します。

1. `kubectl` のcurrent contextが `rancher-desktop` であること
2. Kubernetes NodeがReadyであること
3. default StorageClassとTraefik IngressClassが存在すること
4. PostgreSQL StatefulSetがReadyになること
5. Redmine DeploymentがReadyになること
6. `http://redmine.localhost` がHTTP応答を返すこと

途中で失敗した場合は、Pod、PVC、Ingress、Event、PostgreSQLおよびRedmineのログを自動表示します。

## 実行時間の上限を変更する

既定のKubernetes待機時間は300秒です。

```bash
TIMEOUT=600s ./scripts/bootstrap-rancher-desktop.sh
```

## context名を明示的に変更する

通常は変更しません。別名のcontextを意図的に使う場合だけ指定します。

```bash
EXPECTED_CONTEXT=my-context ./scripts/bootstrap-rancher-desktop.sh
```

## 再実行

`kubectl apply` を使っているため、同じ環境に再実行できます。Rancher DesktopをFactory Resetした後は、新しいPVCとデータベースを含む環境が作成されます。
