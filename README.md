# Project 02: Docker + Jenkins + AWS

Source: https://github.com/Vennilavanguvi/kanban-dashboard

GitHub push → Jenkins → Docker build → secret scan → Docker Hub → EC2 pull → deployment → validation/rollback.

## Application configuration

React/TypeScript/Vite; Node 24 build runtime. No required environment variables or backend. Tasks persist in browser localStorage and are not shared between devices.

```bash
npm ci
npm run dev -- --host 127.0.0.1 --port 5173
curl -i http://127.0.0.1:5173/
npm run build
```

Local port: 5173. Build output: dist/. Production: Nginx on container/host port 8081. Start command: nginx -g 'daemon off;'. Jenkins uses 8080.

## One-time AWS setup

1. Fork the source to your GitHub account and commit the supplied files to main.
2. Create Docker Hub repository `YOUR_USERNAME/kanban-dashboard` and a scoped push token.
3. Launch Ubuntu 24.04 x86_64 EC2. Use an approved 2-vCPU/4-GiB instance with at least 30 GiB storage for Jenkins and builds. Record region, instance ID and public IP. Monitor disk usage. Stable addressing avoids webhook changes after stop/start.
4. Security group: TCP 22 from your IP /32; TCP 8080 from your IP /32 plus GitHub webhook source ranges; TCP 8081 from your intended audience (public access only if required for the demo). Do not open 18081. Obtain current GitHub hook CIDRs from https://api.github.com/meta. Do not expose SSH/Jenkins to all addresses to fix connectivity.
5. Clone/copy this repository onto EC2. Run `sudo bash deploy/setup-ec2.sh`. Reconnect SSH for Docker group membership.
6. Visit http://EC2_PUBLIC_IP:8080. Unlock using the initial password file printed by setup, create an administrator and install suggested plugins plus Pipeline, Git, GitHub, Docker Pipeline and Credentials Binding. Keep anonymous administration/build permissions disabled. Restricted HTTP is for a classroom demo; use HTTPS for production.

References: [Jenkins installation](https://www.jenkins.io/doc/book/installing/linux/) and [Docker installation](https://docs.docker.com/engine/install/ubuntu/).

## Jenkins configuration

1. Manage Jenkins → Nodes → Built-In Node: label `docker-ec2`; one executor. This assignment builds and deploys on the same EC2 host. Only trusted repository writers may edit this pipeline: Docker group access grants host administration privileges.
2. Credentials → Global → Username with password: ID `dockerhub`, username = Docker Hub username, password = token. Never put the token in source, screenshots or command arguments.
3. The Docker Hub/same-host design needs no AWS API keys. EC2 provisioning is separate; deployment uses the local Docker daemon. If the rubric strictly requires an AWS credential-store entry, use an approved least-privilege credential with the AWS Credentials plugin. It is not needed by this Jenkinsfile. Prefer an instance IAM role for actual AWS API operations.
4. New Item → Pipeline → Pipeline script from SCM → Git → your fork URL → branch `*/main` → Script Path `Jenkinsfile`. Private repositories require a separate read-only GitHub credential.
5. The first build registers parameters/triggers and intentionally rejects the placeholder registry name. Set `DOCKERHUB_REPO` to your real username/repository and build. Application tags contain build number and commit SHA; deployment does not use latest.
6. GitHub fork → Settings → Webhooks: payload URL `http://EC2_PUBLIC_IP:8080/github-webhook/`, application/json, push events. Restrict network reachability to current GitHub webhook CIDRs. If configuring a webhook secret, configure verification in Jenkins's GitHub plugin as well; a GitHub-only secret is not enough.
7. Push a visible app change to main. Capture GitHub delivery HTTP 200, Jenkins's automatically triggered build cause/commit and the new image tag. Do not click Build Now for the webhook proof.

## Docker and deployment

```bash
docker build -t kanban-dashboard:local .
docker run -d --name kanban-local --memory 128m --cpus .5 -p 8081:8081 kanban-dashboard:local
curl -i http://localhost:8081/
docker inspect -f '{{.State.Health.Status}} user={{.Config.User}}' kanban-local
```

The multi-stage image copies only built app artifacts into a minimal Nginx runtime. It runs as UID/GID 10001 with a read-only filesystem, temporary /tmp, dropped capabilities and no-new-privileges. No credentials enter the build. The pipeline scans the image for secrets and archives results. A successful scanner result is evidence for that scan, not a guarantee against every possible secret. Pin base/scanner image digests for longer-term reproducibility.

Each app container is limited to 128 MiB, 0.5 CPU and 100 processes, with bounded logs. Static Nginx hosting is small; these initial limits leave resources for Jenkins and builds on a 4-GiB host. Validate with docker stats under expected load. Candidate and live containers briefly coexist.

The deployment pulls the pushed tag and tests a candidate on loopback port 18081 before replacing the running app. The old container is retained for rollback. Deployment failure restores and health-checks the previous release; first deployment has no prior release to restore. There is brief downtime at the switch. No zero-downtime bonus is claimed.

After a successful release, run a build with FAIL_AFTER_DEPLOY=true to demonstrate an intentional failed deployment and automatic rollback. Capture the failed stage, rollback.txt, console output and restored image. Set the parameter back to false and push a commit for the final successful automatic release.

## Evidence and submission

```bash
docker ps
docker inspect -f '{{.State.Health.Status}} user={{.Config.User}} memory={{.HostConfig.Memory}} cpus={{.HostConfig.NanoCpus}}' kanban-app
docker logs --tail 100 kanban-app
docker stats --no-stream kanban-app
curl -i http://127.0.0.1:8081/healthz
curl -i http://EC2_PUBLIC_IP:8081/
```

The pipeline archives metadata, secret scan, logs, HTTP response, image version and rollback results. Health checks verify Nginx and the expected app HTML; open the browser and test task creation for functional proof.

On a second clean Docker host, pull the exact versioned tag and run it. Pulling on the Jenkins build host does not satisfy the separate clean-machine proof.

Submit:
- Your GitHub repository URL, Dockerfile, Jenkinsfile and README.
- Docker Hub URL and screenshot of versioned tags.
- Actual app URL http://EC2_PUBLIC_IP:8081/ and app screenshot.
- EC2 and security-group screenshots.
- Local HTTP/browser proof, successful build and container non-root/scan evidence.
- Successful and failed Jenkins stage views, console output and rollback evidence.
- GitHub webhook delivery, automatic build cause and matching commit/image tag.
- docker ps/logs/health/resource limits and clean-host pull evidence.

See evidence/STATUS.md for actual validation status. Do not submit placeholders or unexecuted steps as completed evidence.
