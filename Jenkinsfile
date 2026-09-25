pipeline {
  agent { label 'docker-ec2' }
  options { timestamps(); disableConcurrentBuilds(); skipDefaultCheckout(true); buildDiscarder(logRotator(numToKeepStr: '15')) }
  triggers { githubPush() }
  parameters {
    string(name: 'DOCKERHUB_REPO', defaultValue: 'praveen09it/kanban-dashboard', description: 'Existing Docker Hub repository')
    booleanParam(name: 'FAIL_AFTER_DEPLOY', defaultValue: false, description: 'Rollback demonstration: use only after a successful release')
  }
  stages {
    stage('Checkout') {
      steps {
        deleteDir()
        checkout scm
        script {
          if (!(params.DOCKERHUB_REPO ==~ /[a-z0-9][a-z0-9_-]*\/[a-z0-9][a-z0-9._-]*/)) { error('Set DOCKERHUB_REPO to your real Docker Hub repository') }
          env.IMAGE = "${params.DOCKERHUB_REPO}:${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim()}"
        }
      }
    }
    stage('Build image') {
      steps { sh 'mkdir -p evidence; docker build --pull -t "$IMAGE" .; docker image inspect "$IMAGE" > evidence/image-inspect.json' }
    }
    stage('Secret scan') {
      steps {
        sh '''docker run --rm --user "$(id -u):$(id -g)" --group-add "$(stat -c '%g' /var/run/docker.sock)" -e TRIVY_CACHE_DIR=/tmp/trivy -v /var/run/docker.sock:/var/run/docker.sock -v "$WORKSPACE/evidence:/reports" aquasec/trivy:latest image --scanners secret --exit-code 1 --format json --output /reports/secret-scan.json "$IMAGE"'''
      }
    }
    stage('Registry login and push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_TOKEN')]) {
          sh '''
            set +x
            export DOCKER_CONFIG=$(mktemp -d)
            trap 'rm -rf "$DOCKER_CONFIG"' EXIT
            printf '%s' "$REGISTRY_TOKEN" | docker login -u "$REGISTRY_USER" --password-stdin
            docker push "$IMAGE"
          '''
        }
      }
    }
    stage('Deploy and health-check on EC2') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_TOKEN')]) {
          sh '''
            set +x
            export DOCKER_CONFIG=$(mktemp -d)
            trap 'rm -rf "$DOCKER_CONFIG"' EXIT
            printf '%s' "$REGISTRY_TOKEN" | docker login -u "$REGISTRY_USER" --password-stdin
            bash deploy/deploy.sh
          '''
        }
      }
    }
    stage('Validate release') {
      steps {
        sh '''
          test "$(docker inspect -f '{{.State.Running}}' kanban-app)" = true
          test "$(docker inspect -f '{{.State.Health.Status}}' kanban-app)" = healthy
          test "$(docker inspect -f '{{.Config.User}}' kanban-app)" = 10001:10001
          curl -fsS http://127.0.0.1:8081/healthz | grep -qx healthy
          curl -fsS http://127.0.0.1:8081/ | grep -q kanban-style-task-manager
        '''
      }
    }
  }
  post {
    always { archiveArtifacts artifacts: 'evidence/**', allowEmptyArchive: true }
    success { echo 'Versioned release deployed and healthy.' }
    failure { echo 'Release failed. Inspect stage logs and rollback artifact; do not report this build as deployed.' }
  }
}
