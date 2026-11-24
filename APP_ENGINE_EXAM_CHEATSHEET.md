# 🚀 Google App Engine (GAE) — Exam Cheatsheet (GCP Associate Cloud Engineer & Cloud Architect)

Ce guide de révision regroupe **l'intégralité des concepts, commandes CLI, scénarios d'examen et pièges classiques** concernant Google App Engine pour les certifications GCP (ACE / PCA).

---

## 📑 Sommaire
1. [Architecture & Hiérarchie App Engine](#1-architecture--hiérarchie-app-engine)
2. [Standard vs. Flexible : Le Comparatif Ultime d'Examen](#2-standard-vs-flexible--le-comparatif-ultime-dexamen)
3. [Anatomie des Fichiers de Configuration (`app.yaml`, `dispatch.yaml`, `cron.yaml`)](#3-anatomie-des-fichiers-de-configuration)
4. [Toutes les Commandes `gcloud app` Indispensables](#4-toutes-les-commandes-gcloud-app-indispensables)
5. [Gestion du Trafic (Canary, Blue/Green & A/B Testing)](#5-gestion-du-trafic-canary-bluegreen--ab-testing)
6. [Types de Scaling (Automatic, Basic, Manual)](#6-types-de-scaling)
7. [Scénarios Typiques & Questions Pièges de l'Examen](#7-scénarios-typiques--questions-pièges-de-lexamen)

---

## 1. Architecture & Hiérarchie App Engine

Google App Engine structure les applications sous une hiérarchie stricte à 4 niveaux :

```
┌────────────────────────────────────────────────────────┐
│                   GCP Project                          │
│  └─ App Engine Application (1 seule par projet GCP)   │
│       ├─ Service: "default" (Frontend)                 │
│       │    ├─ Version: v1 (90% trafic) ── Instances    │
│       │    └─ Version: v2 (10% trafic) ── Instances    │
│       └─ Service: "backend" (API)                      │
│            └─ Version: prod (100% trafic) ── Instances │
└────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> **Règles d'or absolues pour l'examen :**
> 1. **1 seule application App Engine par projet GCP.**
> 2. **Région irréversible :** Une fois la région de l'application choisie (`gcloud app create --region=...`), **il est strictement impossible de la modifier** ou de supprimer l'application du projet. Si vous voulez changer de région, vous devez créer un nouveau projet GCP.
> 3. **Le service `default` est obligatoire :** Le premier service déployé doit obligatoirement être nommé `default`.

---

## 2. Standard vs. Flexible : Le Comparatif Ultime d'Examen

C'est **la question la plus récurrente** aux examens GCP. Retenez ce tableau par cœur :

| Caractéristique | App Engine Standard | App Engine Flexible |
| :--- | :--- | :--- |
| **Hôte sous-jacent** | Sandbox sécurisée gérée par Google | **Machines Virtuelles Compute Engine (VM)** |
| **Temps de démarrage** | **Millisecondes / Secondes** | **Plusieurs minutes** (le temps de boot des VM) |
| **Scale to Zero (0 instance)**| **OUI** (aucun coût d'instance si 0 requête) | **NON** (minimum 1 VM active = coût fixe) |
| **Support Docker / Container** | ❌ Non (Runtimes pré-packagés Google uniquement) | ✅ **OUI** (`runtime: custom` ou image Docker) |
| **Accès Root / SSH** | ❌ Non | ✅ **OUI** (`gcloud app instances enable-debug`) |
| **Accès au système de fichiers** | Lecture seule (+ écriture éphémère dans `/tmp`) | Écriture sur disque local VM (non persistant après reboot) |
| **Réseau & VPC** | Nécessite un **Serverless VPC Access Connector** | Connecté **directement au VPC** |
| **Modèle de facturation** | Heures d'instance (Classes F / B) + Free Tier généreux | Facturation VM Compute Engine (vCPU, RAM, Disque) |
| **Tâches en arrière-plan (Background threads)** | Non (bloqué ou limité au temps de la requête) | ✅ Oui (threads persistants en continu) |
| **Protocoles supportés** | HTTP / HTTPS (WebSockets en bêta/limité) | HTTP / HTTPS / **WebSockets natifs** |

---

## 3. Anatomie des Fichiers de Configuration

### 3.1 `app.yaml` — Standard Environment (Python 3)
```yaml
runtime: python311
instance_class: F1  # F1 (défaut, 256MB), F2 (512MB), F4 (1GB)

# Commande de démarrage WSGI
entrypoint: gunicorn -b :$PORT main:app

# Variables d'environnement
env_variables:
  DATABASE_URL: "postgresql://user:pass@10.0.0.3/db"

# Scaling automatique avec scale-to-zero
automatic_scaling:
  min_instances: 0
  max_instances: 5
  target_cpu_utilization: 0.65

# Gestion des assets statiques
handlers:
  - url: /static
    static_dir: static
  - url: /.*
    script: auto
```

### 3.2 `app.yaml` — Flexible Environment (Docker / Custom)
```yaml
runtime: custom
env: flex

# Spécification des ressources de la VM Compute Engine sous-jacente
resources:
  cpu: 1
  memory_gb: 2
  disk_size_gb: 10

# Scaling Flexible (au moins 1 instance obligatoire !)
automatic_scaling:
  min_num_instances: 1
  max_num_instances: 4
  cpu_utilization:
    target_utilization: 0.7
```

### 3.3 `dispatch.yaml` — Routage multi-services
Permet d'acheminer le trafic entrant vers le bon service selon l'URL :
```yaml
dispatch:
  # Envoie les requêtes /api/* vers le service 'backend'
  - url: "*/api/*"
    service: backend

  # Tout le reste va sur le service par défaut
  - url: "*/*"
    service: default
```
*Commande de déploiement :* `gcloud app deploy dispatch.yaml`

---

## 4. Toutes les Commandes `gcloud app` Indispensables

### Initialisation & Déploiement
```bash
# 1. Créer l'application App Engine dans la région europe-west1 (1 fois par projet)
gcloud app create --region=europe-west1

# 2. Déployer l'application (promeut automatiquement la version à 100% du trafic)
gcloud app deploy

# 3. Déployer SANS lui envoyer de trafic (INDISPENSABLE pour test pré-prod / Canary)
gcloud app deploy --no-promote

# 4. Spécifier manuellement un identifiant de version
gcloud app deploy --version=v2 --no-promote

# 5. Déployer un service spécifique ou des règles de dispatch
gcloud app deploy backend.yaml
gcloud app deploy dispatch.yaml

# 6. Déployer une image Docker pré-packagée (Flexible)
gcloud app deploy --image-url=europe-west1-docker.pkg.dev/PROJET/REPO/IMAGE:1.0.1
```

### Consultation & Diagnostic
```bash
# Ouvrir l'application dans le navigateur par défaut
gcloud app browse

# Ouvrir une version ou un service spécifique
gcloud app browse --service=backend --version=v2

# Lister les services, versions et instances
gcloud app services list
gcloud app versions list
gcloud app instances list

# Suivre les logs en temps réel
gcloud app logs tail -s default
```

### Arrêt & Économie de Coûts
```bash
# Arrêter une version spécifique (très important pour couper les VM payantes de Flexible)
gcloud app versions stop v1

# Supprimer une version (ATTENTION : impossible de supprimer une version qui reçoit 100% du trafic)
gcloud app versions delete v1
```

---

## 5. Gestion du Trafic (Canary, Blue/Green & A/B Testing)

La bascule et la répartition de trafic sont au cœur des questions d'examen.

### 5.1 Promotion instantanée (Blue/Green Deployment)
Basculer instantanément 100% des utilisateurs vers la nouvelle version `v2` :
```bash
gcloud app services set-traffic default --splits=v2=1
```

### 5.2 Répartition de trafic (Canary / A/B Testing)
Envoyer 80% du trafic sur la version stable `v1` et 20% sur la version test `v2` :
```bash
gcloud app services set-traffic default --splits=v1=0.8,v2=0.2 --split-by=cookie
```

### 5.3 Les 3 mécanismes de `--split-by` (Question Piège fréquente !)

| Type de Split | Mécanisme | Cas d'usage recommandé à l'examen |
| :--- | :--- | :--- |
| **`--split-by=cookie`** *(Recommandé)* | Injecte un cookie HTTP (`GOOGAPPUID`) dans le navigateur client. | **A/B Testing & Expérience utilisateur stable** : Un utilisateur donné reste sur la même version tout au long de sa session. |
| **`--split-by=ip`** | Hache l'adresse IPv4/IPv6 du client. | Utile pour les clients HTTP qui ne gèrent pas les cookies (ex: API REST, applications mobiles). Attention derrière un NAT d'entreprise (tout le bureau va sur la même version). |
| **`--split-by=random`** | Choisit une version au hasard à chaque requête HTTP. | ❌ À éviter pour du web interactif ! Une page peut se charger en `v1` et le clic suivant basculer en `v2`. |

---

## 6. Types de Scaling

App Engine propose 3 types de scaling définis dans `app.yaml` :

### 1. `automatic_scaling` *(Standard & Flexible)*
* Démarre et arrête des instances selon le trafic, la latence cible ou l'utilisation CPU.
* **Standard :** supporte `min_instances: 0` (scale-to-zero).
* **Flexible :** `min_num_instances` vaut obligatoirement au minimum **1**.

### 2. `basic_scaling` *(Standard uniquement)*
* Crée des instances quand des requêtes arrivent, et les éteint quand l'instance devient inactive après un délai (`idle_timeout: 10m`).
* Moins réactif que l'automatique, parfait pour les traitements par lots ou faibles trafics.

### 3. `manual_scaling` *(Standard & Flexible)*
* Vous définissez un nombre fixe d'instances qui tournent en continu sans interruption :
  ```yaml
  manual_scaling:
    instances: 3
  ```

---

## 7. Scénarios Typiques & Questions Pièges de l'Examen

### ❓ Scénario 1 : Tester une version avant de lui router le trafic
> **Question :** *"Vous devez déployer la version `v2` de votre application App Engine sans impacter les utilisateurs en production, exécuter des tests de validation sur cette version, puis basculer le trafic. Que faire ?"*
> 
> 👉 **Solution d'examen :**
> 1. Déployer avec le flag `--no-promote` :  
>    `gcloud app deploy --version=v2 --no-promote`
> 2. Tester l'URL dédiée de la version (`https://v2-dot-[SERVICE]-dot-[PROJECT_ID].appspot.com` ou `gcloud app browse --version=v2`).
> 3. Basculer le trafic :  
>    `gcloud app services set-traffic default --splits=v2=1`.

---

### ❓ Scénario 2 : Arrêter la facturation d'une version
> **Question :** *"Une application critique utilise App Engine Flexible. Pour des raisons d'audit, vous devez conserver le code et la configuration d'une ancienne version sans la supprimer, mais sans payer pour ses VM. Quelle commande exécuter ?"*
> 
> 👉 **Solution d'examen :**  
> `gcloud app versions stop <VERSION_ID>`  
> *(La suppression `delete` détruirait la version ; le simple fait qu'elle ne reçoive pas de trafic sur Flexible continue de faire tourner 1 VM minimum payante).*

---

### ❓ Scénario 3 : Choix du service Serverless (App Engine vs Cloud Run)
> **Question :** *"Vous avez une application conteneurisée Docker avec des pics de charge imprévisibles et de longues périodes creuses. Vous voulez minimiser les coûts à zéro pendant les périodes creuses et un temps de réponse rapide. Que choisir ?"*
> 
> * A. App Engine Flexible
> * B. Compute Engine avec Managed Instance Group
> * C. Google Cloud Run
> * D. GKE avec cluster Autopilot
> 
> 👉 **Bonne réponse : C (Cloud Run)**.  
> *Pourquoi pas A ?* App Engine Flexible ne scale jamais à 0 et met plusieurs minutes à démarrer.

---

### ❓ Scénario 4 : Connexion à Cloud SQL en réseau privé depuis App Engine Standard
> **Question :** *"Votre application App Engine Standard doit communiquer avec une base Cloud SQL PostgreSQL qui n'a qu'une adresse IP privée dans votre VPC. Que devez-vous configurer ?"*
> 
> 👉 **Solution d'examen :**  
> Créer un **Serverless VPC Access Connector** (connecteur d'accès VPC sans serveur) dans la même région, et l'associer dans le fichier `app.yaml` :
> ```yaml
> vpc_access_connector:
>   name: projects/PROJECT_ID/locations/REGION/connectors/CONNECTOR_NAME
> ```
