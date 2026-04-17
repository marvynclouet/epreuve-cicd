# Rapport de réalisation — Projet DevSecOps TaskAPI

## Choix techniques

J'ai utilisé Alpine comme image de base parce que c'est léger et qu'il y a peu de paquets installés par défaut, ce qui réduit la surface d'attaque. La version de Node.js est fixée à `20.19.0` exactement, pas de tag flottant comme `node:lts` qui peut changer entre deux builds sans qu'on le voie.

Le Dockerfile est en multi-stage. Le premier stage installe les dépendances de production avec `npm ci --only=production`, le second récupère uniquement node_modules et server.js. Résultat : npm, Jest, Supertest et tout le cache ne sont pas dans l'image finale. C'est plus propre et plus petit.

Pour le pipeline j'ai mis Gitleaks pour les secrets, Semgrep pour l'analyse statique, Trivy deux fois (une fois sur les dépendances npm, une fois sur l'image Docker parce que ce sont deux périmètres différents) et Syft pour générer un SBOM en format CycloneDX. Le pipeline bloque uniquement sur les vulnérabilités CRITICAL. Bloquer sur HIGH crée trop de faux positifs et en pratique ça finit par être ignoré.

En Kubernetes j'ai ajouté une NetworkPolicy deny-all par défaut sur le namespace. Seuls les flux nécessaires sont autorisés explicitement : l'ingress sur le port 3000, la sortie vers PostgreSQL et Redis, et le scraping Prometheus.

## Ce qui a fonctionné

L'intégration de prom-client s'est faite assez simplement. Un middleware Express démarre un timer au début de chaque requête et enregistre les métriques quand la réponse est envoyée via `res.on('finish', ...)`. Le Counter et l'Histogram couvrent ce qui est demandé.

Pour les tests, j'ai utilisé le pattern `require.main === module` pour ne démarrer le serveur que quand le fichier est lancé directement. Comme ça Jest peut importer server.js sans ouvrir de port et les tests ne se bloquent pas mutuellement.

Les jobs `test` et `security` tournent en parallèle dans le pipeline après le build, ce qui évite d'attendre inutilement. Le job `package` n'est lancé que si les deux ont réussi.

## Difficultés

Le point qui m'a pris du temps c'est `readOnlyRootFilesystem: true` en Kubernetes. Le filesystem du conteneur est en lecture seule mais Node.js a besoin d'écrire des fichiers temporaires. J'ai dû ajouter un volume emptyDir monté sur `/app/tmp` pour contourner ça. Sans ce volume l'application démarre mais crash dès qu'elle essaie d'écrire quelque chose.

La NetworkPolicy pour le scraping Prometheus suppose aussi que Prometheus tourne dans un namespace `monitoring` avec le label `app: prometheus`. Si ce n'est pas le cas sur le cluster, le scraping échoue sans message d'erreur, juste pas de données.

## Le stage deploy

Le stage deploy ne déploie pas vraiment. Il fait un `echo` de la commande kubectl pour simuler le comportement. En production il faudrait exécuter `kubectl set image deployment/taskapi app=taskapi:<sha>` contre un vrai cluster, avec les credentials injectés en secrets GitHub Actions. Cette commande déclenche un rolling update côté Kubernetes, les pods sont remplacés progressivement sans coupure de service. Le SHA du commit dans le tag de l'image garantit qu'on déploie exactement ce qui a été scanné.

## Améliorations possibles

Les Secrets Kubernetes sont en base64, ce n'est pas du chiffrement. En production il faudrait intégrer HashiCorp Vault ou l'External Secrets Operator pour avoir des credentials chiffrés avec rotation automatique.

OPA Gatekeeper permettrait d'appliquer les règles de sécurité directement au niveau du cluster et de rejeter tout pod qui ne respecte pas les contraintes avant même qu'il soit schedulé. C'est plus fiable qu'un SecurityContext qu'on peut oublier de mettre.

Dependabot ou Renovate pour les mises à jour automatiques serait utile aussi, sinon le projet accumule des CVEs au fil du temps.

## Références du sujet introuvables

J'ai cherché CVE-2024-9999, ANSSI-2025-COR-09 alias Ghost-24 et la règle R-45b dans les bases officielles (NVD, site ANSSI) et je n'ai rien trouvé qui corresponde. Ces identifiants ne semblent pas exister dans les publications officielles. J'ai fait tourner Trivy sur mon image et les vulnérabilités remontées sont bien réelles, notamment CVE-2025-15467 sur OpenSSL classée CRITICAL, mais les trois références mentionnées dans le sujet n'ont pas pu être analysées faute de source.
