// Jenkins pipeline that builds/tests microservices, runs quality gates, and deploys to Kubernetes

// 1) Khai báo danh sách services dùng chung
def services = ['orders', 'payments', 'users']

// 2) Hàm helper để lặp qua từng service
def runForServices(closure) {
  services.each { svc ->
    closure(svc)
  }
}

pipeline {
  agent any

  environment {
    AWS_REGION        = 'us-east-1'
    DOCKER_REGISTRY   = '123456789012.dkr.ecr.us-east-1.amazonaws.com'
    SONAR_PROJECT_KEY = 'microservices-monorepo'
    SONARQUBE_ENV     = 'SonarQubeServer'
    TRIVY_SEVERITY    = 'HIGH,CRITICAL'
  }

  options {
    skipDefaultCheckout(false)
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install Dependencies & Unit Tests') {
      steps {
        script {
          runForServices { svc ->
            dir("services/${svc}") {
              sh 'npm install'
              sh 'npm test'
            }
          }
        }
      }
    }

    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv(env.SONARQUBE_ENV) {
          sh "sonar-scanner " +
             "-Dsonar.projectKey=${SONAR_PROJECT_KEY} " +
             "-Dsonar.sources=services " +
             "-Dsonar.javascript.lcov.reportPaths=coverage/lcov.info"
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Docker Build') {
      steps {
        script {
          runForServices { svc ->
            def image = "${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"
            dir("services/${svc}") {
              sh "docker build -t ${image} ."
            }
            sh "docker tag ${image} ${DOCKER_REGISTRY}/${svc}:latest"
          }
        }
      }
    }

    stage('Container Security (Trivy)') {
      steps {
        // Dùng double-quote để biến TRIVY_SEVERITY được expand
        sh "trivy fs --exit-code 1 --severity ${TRIVY_SEVERITY} --skip-dirs .git ."
      }
    }

    stage('Push Images') {
      when {
        branch 'main'
      }
      steps {
        withAWS(region: env.AWS_REGION, credentials: 'aws-ecr-creds') {
          sh "aws ecr get-login-password | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}"
        }
        script {
          runForServices { svc ->
            sh "docker push ${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"
            sh "docker push ${DOCKER_REGISTRY}/${svc}:latest"
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      when {
        branch 'main'
      }
      steps {
        // Dùng credential loại Secret file với ID = 'kubeconfig'
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
          sh '''
            kubectl config use-context microservices
            kubectl apply -k k8s/overlays/prod
          '''
        }
      }
    }
  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'services/*/junit-report.xml'
      archiveArtifacts artifacts: 'services/*/coverage/**/*', allowEmptyArchive: true
    }
    failure {
      // Nếu không có SMTP thì có thể comment block mail này lại
      mail to: 'devops@example.com',
           subject: "${env.JOB_NAME} #${env.BUILD_NUMBER} failed",
           body: "Check Jenkins for details: ${env.BUILD_URL}"
    }
  }
}
