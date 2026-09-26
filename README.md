# Project 02 — Kanban deployment using Docker Jenkins and AWS

## Submission links

- GitHub: https://github.com/praveenpreni/kanban-dashboard
- Docker Hub: https://hub.docker.com/r/praveen09it/kanban-dashboard
- Live app: http://15.206.164.254:8081/
- Jenkins: http://15.206.164.254:8080/ (restricted administrator access)
- Original source: https://github.com/Vennilavanguvi/kanban-dashboard

## Verified outcome

GitHub → Jenkins → Docker build → secret scan → versioned Docker Hub push → EC2 pull → deployment → health validation or rollback.

Build 2 was triggered automatically by a GitHub push and deployed the changed heading. Build 3 intentionally failed after deployment and restored the previous healthy release. Build 4 completed successfully.

## Application setup

React 18, TypeScript and Vite. No required environment variables or backend database. Tasks persist in browser localStorage and are not shared between browsers.

```bash
npm ci
npm run dev -- --host 127.0.0.1 --port 5173
curl -i http://127.0.0.1:5173/
npm run build
npm run lint
```

Local HTTP/browser rendering, production build and lint passed. Build output is `dist/`. Production uses Nginx on port 8081 with start command `nginx -g 'daemon off;'`.

## AWS infrastructure

| Setting | Value |
|---|---|
| Region | Mumbai ap-south-1 |
| Instance | i-00eb0dd7eaa35609b |
| OS | Ubuntu 24.04 LTS x86_64 |
| Type | t3.small, 2 vCPU, 2 GiB RAM |
| Storage | 30 GiB gp3, delete on termination enabled |
| Swap | 2 GiB |
| Public IP | 15.206.164.254 |
| Security group | project02-jenkins-sg |
| Jenkins | 8080, one executor, label docker-ec2 |
| Application | 8081 |

SSH port 22 and Jenkins administrator access are restricted to the administrator IP. Port 8080 also permits GitHub's published IPv4 webhook ranges. Port 8081 is public for evaluation. Candidate port 18081 binds only to loopback.

Hook ranges checked on 25 September 2026: 192.30.252.0/22, 185.199.108.0/22, 140.82.112.0/20, 143.55.64.0/20. Refresh these from https://api.github.com/meta when necessary.

## Docker and security

The multi-stage Dockerfile builds using Node 24 Alpine and copies only built app artifacts into Nginx Alpine. Runtime UID/GID is 10001, configured with USER. Only port 8081 is exposed. HEALTHCHECK requests /healthz every 10 seconds.

.dockerignore excludes dependencies, Git history, environment files, key files, logs and local work. Trivy secret scanning gates the pipeline and archives its report. Scanner success is not a guarantee against all secrets or vulnerabilities.

Containers use 128 MiB memory, 0.5 CPU, a 100-process limit, read-only root filesystem, 32 MiB temporary /tmp, dropped capabilities and no-new-privileges. Logs rotate at 10 MiB with three files. These starting limits reserve space for Jenkins and builds on the 2 GiB host. Swap helps memory pressure but does not replace RAM performance. Validate limits with docker stats under load.

## Jenkins and credentials

Installed plugins include Pipeline, Git, GitHub, Docker Pipeline and Credentials Binding. Job `kanban-dashboard-pipeline` loads `Jenkinsfile` from this public repository's main branch. The registry credential is a Jenkins Username with password entry with ID `dockerhub`, username `praveen09it` and a Docker Hub access token. No secrets are committed.

No AWS API credential is needed: deployment uses Docker locally on EC2 and makes no AWS API calls. Provisioning was performed separately through the IAM console. This is an explicit deviation from the rubric's AWS credential-store entry, avoiding unnecessary permanent keys.

The built-in node is used for this single-host lab. Docker access grants host-level privilege, so only trusted repository writers may edit this pipeline. Separate build agents are recommended outside this lab.

## Pipeline and rollback

1. Checkout main and calculate a build-number plus Git-SHA tag.
2. Build the image and archive metadata.
3. Scan the image for secrets and fail on findings.
4. Authenticate using Jenkins credentials and push the versioned image.
5. Pull the image, start a candidate on 127.0.0.1:18081 and validate health plus expected HTML.
6. Retain the previous container and replace the app on 8081.
7. Validate running state, health, non-root identity and HTTP response; archive evidence.

Deployment failure restores and rechecks the previous release. First deployment has no previous release to restore. There is a brief interruption at the switch; zero downtime is not claimed.

| Build | Result |
|---|---|
| 1 | Manual initial run, SUCCESS |
| 2 | GitHub push by praveenpreni, SUCCESS; updated heading deployed |
| 3 | FAIL_AFTER_DEPLOY=true, intentional FAILURE; previous release restored and validated |
| 4 | FAIL_AFTER_DEPLOY=false, SUCCESS |

Build 5 was subsequently observed healthy on the live host after the README update (image `5-9bb66c94053a`).

Build 4 independently tested image: `praveen09it/kanban-dashboard:4-79eb5c0e87ae`.

## Webhook

Payload URL: `http://15.206.164.254:8080/github-webhook/`; application/json; push events; Active enabled. Jenkinsfile registers githubPush(). The successful ping and build 2 console's GitHub-push cause demonstrate connectivity and automatic triggering.

This restricted classroom demo uses HTTP and no webhook shared secret. HTTPS and matching signature verification are future hardening work.

## Validation and evidence

```bash
docker ps
docker inspect -f '{{.State.Health.Status}} user={{.Config.User}} memory={{.HostConfig.Memory}} cpus={{.HostConfig.NanoCpus}}' kanban-app
docker logs --tail 100 kanban-app
docker stats --no-stream kanban-app
curl -i http://127.0.0.1:8081/healthz
curl -i http://15.206.164.254:8081/
```

Archived evidence includes image/container inspection, secret scan JSON, logs, HTTP response and image tag. Build 3 includes rollback evidence. Screenshots show the updated live app, tags, stage results and GitHub build cause.

## Independent pull verification

Independent pull/run verification passed on 26 September 2026 on a separate fresh Ubuntu 24.04 EC2 host (i-0bdfea7db086201f8, 13.127.202.254). Docker was installed on the empty host and image 4-79eb5c0e87ae was pulled from Docker Hub without copying or building source. The container was healthy, ran as 10001:10001 with 128 MiB memory, 0.5 CPU, a 100-process limit and read-only root filesystem. HTTP health and HTML checks passed. See evidence/clean-machine-pull.txt.

## Reproduction and cleanup

On a fresh Ubuntu 24.04 host run `sudo bash deploy/setup-ec2.sh` once. Configure the node label, Docker Hub credential and Pipeline-from-SCM job as above. After initial setup, commits trigger automatic deployment.

Keep the app available for approximately one day for evaluation. After evaluation, terminate EC2, confirm the root volume is deleted, check remaining billable resources and revoke the project registry token. Termination makes the app URL unavailable. Stopping alone does not remove storage charges.
