# SECURITY.md — TaskAPI

## Image Docker

L'image est basée sur `node:20.19.0-alpine3.21`. Alpine a peu de paquets donc peu de choses à patcher. Le build multi-stage fait que npm et les dépendances de dev ne se retrouvent pas dans l'image finale. Le processus tourne en tant qu'`appuser` avec l'UID 1001, pas en root.

## Pipeline de sécurité

Gitleaks scanne le dépôt pour détecter des secrets commités par erreur. Semgrep fait l'analyse statique du code. Trivy audite les dépendances npm puis l'image Docker séparément. Syft génère le SBOM en CycloneDX. Si une vulnérabilité CRITICAL est détectée, le pipeline s'arrête. Le stage deploy est simulé avec un echo, en production il faudrait des credentials kubectl injectés via les secrets GitHub Actions.

## Kubernetes

NetworkPolicy avec deny-all par défaut sur le namespace, ouvertures uniquement vers l'ingress sur le port 3000, PostgreSQL sur 5432, Redis sur 6379 et Prometheus pour le scraping. Le SecurityContext du conteneur a `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false` et toutes les capabilities Linux supprimées. Seul `/app/tmp` est accessible en écriture via un volume emptyDir.

## Gestion des secrets

Aucun secret en clair dans le dépôt. Le `.env.example` contient des valeurs fictives pour l'exemple. Le `k8s/secret.yaml` contient des valeurs base64 d'exemple à remplacer par une intégration Vault ou External Secrets Operator avant un vrai déploiement.

## Contact

Issue privée ou `security@startup.io`.
