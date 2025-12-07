pipeline {
  agent any

  environment {
    DOCKERHUB_REPO = "khaledelnabawy1/shortlink-service"
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    CD_REPO = "https://github.com/Khaled-elnabawy/jenkins-argocd-cd.git"
    CD_REPO_PATH = "."
    DEPLOY_FILE = "deployment.yml"
  }

  parameters {
    booleanParam(name: 'UPDATE_CD', defaultValue: true, description: 'Update CD repo after push?')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "docker build -t ${DOCKERHUB_REPO}:${IMAGE_TAG} ."
      }
    }

    stage('Docker Login') {
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')
        ]) {
          sh 'echo $DH_PASS | docker login -u $DH_USER --password-stdin'
        }
      }
    }

    stage('Push Docker Image') {
      steps {
        sh "docker push ${DOCKERHUB_REPO}:${IMAGE_TAG}"
      }
    }

    stage('Update CD repo (bump image tag)') {
      when { expression { return params.UPDATE_CD } }
      steps {
        // نفترض cd-repo-creds مخزن كـ Secret text (GIT token)
        withCredentials([string(credentialsId: 'cd-repo-creds', variable: 'GIT_TOKEN')]) {
          sh '''
            set -e
            rm -rf cd-repo

            REMOTE="${CD_REPO}"
            # شكل URL مع token (لا تعرض التوكن في اللوج)
            REMOTE_URL="https://x-access-token:${GIT_TOKEN}@${REMOTE#https://}"

            # تحقق من الوصول قبل الـ clone
            if git ls-remote "${REMOTE_URL}" >/dev/null 2>&1; then
              git clone "${REMOTE_URL}" cd-repo
              cd cd-repo || exit 2

              cd "${CD_REPO_PATH}" || (echo "Path ${CD_REPO_PATH} not found" && exit 3)

              if [ ! -f "${DEPLOY_FILE}" ]; then
                echo "ERROR: ${DEPLOY_FILE} not found under ${CD_REPO_PATH}"
                exit 4
              fi

              NEW_IMAGE="${DOCKERHUB_REPO}:${IMAGE_TAG}"

              # حاول استخدام yq لو متاح، وإلا استخدم sed كبديل
              if command -v yq >/dev/null 2>&1; then
                yq e '.spec.template.spec.containers[] |= (select(.image == .image) .image = env(NEW_IMAGE))' -i "${DEPLOY_FILE}" || true
              else
                sed -i "s|image: ${DOCKERHUB_REPO}:.*|image: ${NEW_IMAGE}|g" "${DEPLOY_FILE}"
              fi

              git --no-pager diff -- "${DEPLOY_FILE}" || true
              git config user.email "jenkins@ci.local"
              git config user.name "jenkins"

              if git diff --quiet; then
                echo "No changes in ${DEPLOY_FILE}"
              else
                git add "${DEPLOY_FILE}"
                git commit -m "ci: bump image to ${IMAGE_TAG}" || true
                if ! git push origin HEAD; then
                  echo "Warning: git push failed (branch protection or permissions). Please check manually."
                fi
              fi
            else
              echo "CD repo not reachable — skipping CD update"
            fi
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
    success {
      echo "Done: ${DOCKERHUB_REPO}:${IMAGE_TAG}"
    }
    failure {
      echo "Failed"
    }
  }
}
