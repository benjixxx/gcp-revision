# 🚀 CKA Cheatsheet & Speedrun Guide

Ce guide regroupe les réflexes, commandes impératives et configurations indispensables pour réussir l'examen **CKA (Certified Kubernetes Administrator)**.

---

## ⚡ 1. Configuration initiale du terminal (À faire dès la minute 1)

À l'examen, vous êtes dans un shell `bash`. Configurez immédiatement ces alias pour gagner un temps précieux :

```bash
# Alias kubectl et autocomplétion
alias k=kubectl
complete -o default -F __start_kubectl k

# Raccourcis pour la génération rapide de YAML et suppression immédiate
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"

# Configuration de vim pour un YAML propre (indentation 2 espaces)
cat <<EOF > ~/.vimrc
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
syntax on
EOF
```

> **Astuce d'utilisation :**
> Au lieu de taper `--dry-run=client -o yaml`, tapez simplement `$do` !
> Exemple : `k run nginx --image=nginx $do > pod.yaml`

---

## 🧭 2. Gestion des contextes et namespaces

```bash
# Changer de contexte (systématique au début de chaque question !)
k config use-context <context-name>

# Fixer le namespace par défaut dans le contexte courant (évite de taper -n <ns> à chaque fois)
k config set-context --current --namespace=<nom-du-namespace>

# Vérifier le namespace actuel
k config view --minify | grep namespace:
```

---

## 🏗️ 3. Commandes impératives express (Générateurs YAML)

Ne créez **JAMAIS** un fichier YAML à partir de zéro. Générez-le avec `$do` puis éditez-le avec `vim`.

### Pods
```bash
# Pod simple
k run my-pod --image=nginx:alpine

# Pod avec labels, port et variables d'environnement
k run my-pod --image=nginx:alpine --port=80 --env="ENV=prod" --labels="tier=backend"

# Exporter le squelette YAML
k run my-pod --image=nginx $do > pod.yaml
```

### Deployments & Scaling
```bash
# Créer un Deployment avec 3 réplicas
k create deploy my-deploy --image=nginx:1.24 --replicas=3

# Mettre à jour l'image d'un Deployment
k set image deploy/my-deploy nginx=nginx:1.25 --record

# Historique et Rollback
k rollout history deploy/my-deploy
k rollout undo deploy/my-deploy
k rollout restart deploy/my-deploy

# Scaler
k scale deploy/my-deploy --replicas=5
```

### Services & Ingress
```bash
# Exposer un Deployment en ClusterIP (par défaut)
k expose deploy my-deploy --port=80 --target-port=8080 --name=my-svc

# Exposer en NodePort
k expose deploy my-deploy --port=80 --target-port=8080 --type=NodePort --name=my-nodeport

# Créer un Ingress rapidement
k create ingress my-ing --rule="myapp.example.com/api*=my-svc:80"
```

### ConfigMaps & Secrets
```bash
# ConfigMap depuis des valeurs directes
k create cm app-config --from-literal=APP_COLOR=blue --from-literal=MAX_CONN=50

# Secret générique
k create secret generic app-secret --from-literal=DB_PASSWORD=SuperSecret123!
```

### Jobs & CronJobs
```bash
# Job simple
k create job my-job --image=busybox -- sh -c "echo 'hello' && sleep 5"

# CronJob (exécution toutes les 5 minutes)
k create cronjob my-cron --image=busybox --schedule="*/5 * * * *" -- /bin/sh -c "date"
```

### RBAC (Role-Based Access Control)
```bash
# Créer un ServiceAccount
k create sa dev-sa -n my-ns

# Créer un Role avec verbes et ressources précis
k create role pod-reader --verb=get,list,watch --resource=pods,pods/log -n my-ns

# Lier le Role au ServiceAccount
k create rolebinding dev-rb --role=pod-reader --serviceaccount=my-ns:dev-sa -n my-ns

# Vérifier les permissions avec "auth can-i"
k auth can-i list pods --as=system:serviceaccount:my-ns:dev-sa -n my-ns
```

---

## 🔍 4. Troubleshooting & Inspection rapide

```bash
# Trier les événements récents du cluster (panne globale ou scheduling bloqué)
k get events -A --sort-by='.metadata.creationTimestamp'

# Voir pourquoi un Pod plante
k describe pod <pod-name>
k logs <pod-name> --previous            # Logs du conteneur avant son CrashLoopBackOff
k logs <pod-name> -c <container-name>   # Logs d'un conteneur spécifique dans un pod multi-conteneurs

# Suppression instantanée sans attendre les 30s de grace-period
k delete pod <pod-name> $now

# Accéder au pod pour tester le réseau interne
k exec -it <pod-name> -- sh
# Ou lancer un pod jetable de test curl/dns
k run test-net --rm -it --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default
```

---

## 🛠️ 5. Control Plane & Noeuds (Accès SSH / Linux)

### Composants Control Plane (Static Pods)
* Emplacement des manifests sur le nœud Control Plane : `/etc/kubernetes/manifests/`
  * `kube-apiserver.yaml`
  * `kube-controller-manager.yaml`
  * `kube-scheduler.yaml`
  * `etcd.yaml`
* Kubelet surveille ce dossier en permanence. Toute modification d'un fichier redémarre le composant automatiquement.

### Debug sans `kubectl` (avec `crictl`)
```bash
# Lister les conteneurs qui tournent sur la machine
crictl ps
crictl pods

# Voir les logs d'un conteneur planté (ex: l'apiserver)
crictl logs <container-id>

# Kubelet service
systemctl status kubelet
journalctl -u kubelet -n 100 --no-pager
```

### Sauvegarde & Restauration `etcd`
```bash
# Prendre un snapshot
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup.db

# Vérifier le snapshot
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-out=table

# Restaurer dans un nouveau répertoire
ETCDCTL_API=3 etcdctl --data-dir=/var/lib/etcd-restored \
  snapshot restore /tmp/etcd-backup.db
# Puis modifier /etc/kubernetes/manifests/etcd.yaml pour pointer hostPath vers /var/lib/etcd-restored
```

---

## 📊 6. JSONPath (Extraire de la donnée en une ligne)

```bash
# Récupérer l'InternalIP de tous les nœuds
k get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Trier les pods par date de création
k get pods --sort-by='.metadata.creationTimestamp'

# Lister le nom et l'image de tous les pods
k get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

---

## 📚 7. Recherche rapide dans la documentation autorisée

Pendant l'examen, vous avez droit à : `https://kubernetes.io/docs/`
* Tapez directement les mots-clés dans la barre de recherche :
  * `network policy`
  * `pv pvc`
  * `ingress`
  * `etcd backup`
* Utilisez `kubectl explain` quand vous avez un doute sur un champ YAML sans aller sur le web :
  ```bash
  k explain pod.spec.containers.livenessProbe
  k explain ingress.spec.rules --recursive
  ```

