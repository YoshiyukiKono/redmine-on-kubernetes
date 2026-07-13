## 現在の到達点

```text
✓ Namespace
✓ Secret
✓ PostgreSQL (StatefulSet)
✓ PostgreSQL PVC
✓ Redmine (Deployment)
✓ Redmine PVC
✓ ClusterIP Service
✓ Traefik Ingress
✓ ブラウザアクセス
✓ Redmine初回ログイン
```

これは「RedmineをKubernetesで動かす」という目的は既に達成しています。


## 検証


### 目的 

**「データがどこにあるか」「Podを消しても残るのか」を確認すること**

### Step 1 添付ファイルを保存

Redmineで

* Project作成
* チケット作成
* 適当な画像やテキストを添付

します。


### Step 2 Podの中を見る

```bash
kubectl -n redmine-on-kubernetes exec -it deploy/redmine -- sh
```

```bash
ls -R /usr/src/redmine/files
```

添付したファイルが見えることを確認します。


### Step 3 PVを確認

```bash
kubectl get pv
kubectl describe pv
```

PV名を確認。


### Step 4 rdctl shell


```bash
rdctl shell
```

でVMへ入り、

```bash
sudo find /var/lib/rancher/k3s/storage -type f
```

でPV実体を探します。

Rancher Desktop の local-path StorageClass では、PVC の実体は
Rancher Desktop VM 内の /var/lib/rancher/k3s/storage/ に作成される。

ディレクトリ名は次の形式になる。

pvc-<uid>_<namespace>_<pvc-name>

**Pod内のファイル**と**VM内のファイル**が一致することを確認します。


### Step 5 Redmine Pod削除

```bash
kubectl -n redmine-on-kubernetes delete pod -l app=redmine
```

再起動後、

* ログインできる
* プロジェクトが残る
* 添付ファイルが残る

ことを確認します。


### Step 6 PostgreSQL Pod削除

```bash
kubectl -n redmine-on-kubernetes delete pod postgres-0
```

これも同様に確認します。


