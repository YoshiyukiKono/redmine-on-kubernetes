Chapter 1

Verify the Kubernetes Environment

✓ Kubernetes Cluster

✓ Ingress Controller

✓ Dynamic Storage Provisioner

```bash
kubectl config current-context
kubectl get nodes
kubectl get storageclass
kubectl get ingressclass
kubectl -n kube-system get pod

kubectl apply -f manifests/00-namespace.yaml
kubectl get ns redmine-on-kubernetes

kubectl apply -f manifests/01-secret.yaml
kubectl -n redmine-on-kubernetes get secret

kubectl apply -f manifests/10-postgres-pvc.yaml
kubectl apply -f manifests/11-postgres-service.yaml
kubectl apply -f manifests/12-postgres-statefulset.yaml

kubectl -n redmine-on-kubernetes get pvc
kubectl -n redmine-on-kubernetes get pod
kubectl -n redmine-on-kubernetes get svc

kubectl apply -f manifests/20-redmine-pvc.yaml
kubectl apply -f manifests/21-redmine-service.yaml
kubectl apply -f manifests/22-redmine-deployment.yaml

kubectl -n redmine-on-kubernetes get pvc
kubectl -n redmine-on-kubernetes get pod
kubectl -n redmine-on-kubernetes logs deploy/redmine

kubectl apply -f manifests/30-ingress.yaml
kubectl -n redmine-on-kubernetes get ingress
```
http://redmine.localhost

ユーザー: admin
パスワード: admin

平文からSecret生成。本番ではSealed SecretsやExternal Secretsなどに逃がす
