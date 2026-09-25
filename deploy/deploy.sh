#!/usr/bin/env bash
set -Eeuo pipefail
: "${IMAGE:?IMAGE required}"
mkdir -p evidence
name=kanban-app
candidate=kanban-candidate
old=kanban-previous
switched=0
options=(--restart unless-stopped --memory 128m --cpus 0.50 --pids-limit 100 --read-only --tmpfs /tmp:rw,noexec,nosuid,size=32m --cap-drop ALL --security-opt no-new-privileges --log-opt max-size=10m --log-opt max-file=3)
healthy() {
  for i in {1..30}; do
    status=$(docker inspect --format '{{.State.Health.Status}}' "$1")
    if [[ "$status" == healthy ]]; then return 0; fi
    if [[ "$status" == unhealthy ]]; then return 1; fi
    sleep 2
  done
  return 1
}
rollback() {
  code=$?
  trap - ERR
  set +e
  docker logs "$candidate" > evidence/candidate-failure.log 2>&1
  docker logs "$name" > evidence/deployment-failure.log 2>&1
  docker inspect "$name" > evidence/failed-inspect.json 2>&1
  docker rm -f "$candidate" >/dev/null 2>&1
  if [[ "$switched" == 1 ]]; then
    docker rm -f "$name" >/dev/null 2>&1
    if docker inspect "$old" >/dev/null 2>&1; then
      docker rename "$old" "$name"
      docker start "$name"
      if healthy "$name" && curl -fsS http://127.0.0.1:8081/ | grep -q kanban-style-task-manager; then
        echo 'Previous release restored and validated' | tee evidence/rollback.txt
      else
        echo 'ROLLBACK FAILED: operator action required' | tee evidence/rollback.txt
      fi
    else
      echo 'First deployment failed; no previous release exists' | tee evidence/rollback.txt
    fi
  else
    echo 'Candidate failed; live release unchanged' | tee evidence/rollback.txt
  fi
  exit "$code"
}
trap rollback ERR
docker pull "$IMAGE"
docker rm -f "$candidate" >/dev/null 2>&1 || true
docker run -d --name "$candidate" "${options[@]}" -p 127.0.0.1:18081:8081 "$IMAGE"
healthy "$candidate"
curl -fsS http://127.0.0.1:18081/ | grep -q kanban-style-task-manager
docker rm -f "$candidate"
# Keep the old container for automatic rollback. Brief downtime occurs at this switch.
docker rm -f "$old" >/dev/null 2>&1 || true
if docker inspect "$name" >/dev/null 2>&1; then
  docker stop "$name"
  docker rename "$name" "$old"
fi
switched=1
docker run -d --name "$name" "${options[@]}" -p 8081:8081 "$IMAGE"
healthy "$name"
test "$(docker inspect -f '{{.State.Running}}' "$name")" = true
test "$(docker inspect -f '{{.Config.User}}' "$name")" = 10001:10001
curl -fsS http://127.0.0.1:8081/healthz | grep -qx healthy
curl -fsS http://127.0.0.1:8081/ | tee evidence/deployed-response.html | grep -q kanban-style-task-manager
if [[ "${FAIL_AFTER_DEPLOY:-false}" == true ]]; then
  echo 'Intentional failure to demonstrate automatic rollback'
  false
fi
docker ps --filter name=kanban > evidence/docker-ps.txt
docker inspect "$name" > evidence/docker-inspect.json
docker logs "$name" > evidence/docker-logs.txt 2>&1
echo "$IMAGE" > evidence/deployed-image.txt
