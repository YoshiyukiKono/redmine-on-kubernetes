# redmine-on-kubernetes

Redmine を Kubernetes 上で動かし、PVC による永続化を確認するための実践リポジトリです。

## Goal

このリポジトリでは、まず Rancher Desktop 上で Redmine + PostgreSQL を構築し、以下を確認します。

- Redmine を Kubernetes 上で起動する
- PostgreSQL を Kubernetes 上で起動する
- Redmine の添付ファイルを PVC に保存する
- PostgreSQL のデータを PVC に保存する
- Pod を削除してもデータが残ることを確認する
- Rancher Desktop の VM 内で PV の実体を確認する
- Ingress 経由で Redmine にアクセスする

## Phase 1: Rancher Desktop

初期フェーズでは Rancher Desktop の Kubernetes を使用。複数タスクを専用スクリプトで逐次実行

- Kubernetes: Rancher Desktop / K3s
- Ingress Controller: Traefik
- StorageClass: default StorageClass
- Access: Ingress
- PV inspection: rdctl shell

## Architecture

```text
Browser
  |
  | http://redmine.localhost
  v
Ingress / Traefik
  |
  v
Redmine Service
  |
  v
Redmine Pod
  |\
  | \__ PVC: redmine-files
  |
  v
PostgreSQL Service
  |
  v
PostgreSQL Pod
      |
      |__ PVC: postgres-data
````

## Persistent Data

Redmine では、主に2種類のデータを永続化します。

| Component  | Mount Path                 | Purpose        |
| ---------- | -------------------------- | -------------- |
| Redmine    | `/usr/src/redmine/files`   | 添付ファイル         |
| PostgreSQL | `/var/lib/postgresql/data` | Redmine のDBデータ |

## Planned Structure

```text
redmine-on-kubernetes/
├── README.md
├── manifests/
│   ├── 00-namespace.yaml
│   ├── 01-secret.yaml
│   ├── 02-postgres.yaml
│   ├── 03-redmine.yaml
│   ├── 04-services.yaml
│   └── 05-ingress.yaml
├── docs/
│   ├── rancher-desktop.md
│   └── harvester.md
└── history/
```

## Phase 2: Linux

Linux上のKubernetesへの操作についてもスクリプトを追加。タスク完了待機処理を含めたスクリプトによる一括実行

- Kubernetes: K3s (on Harvester)
- Script実行: Ubuntu

RedmineのURLなど、環境固有の条件に応じて、上述の内容とは異なるところがあります。

## Status

Work in progress.
