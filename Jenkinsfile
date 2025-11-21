def services = ['orders', 'payments', 'users']

pipeline {
    agent any

    environment {
        // Docker registry
        DOCKER_REGISTRY = 'docker.io/quannha5'
        // DOCKER_CREDENTIAL = 'docker-registry-cred' // không cần nữa nếu dùng withCredentials

        // SonarQube
        SONARQUBE_ENV      = 'SonarQubeServer'
        SONAR_PROJECT_KEY  = 'microservices-monorepo'
        SONAR_PROJECT_NAME = 'microservices-monorepo'
        SONAR_PROJECT_VER  = '1.0'

        // Optional: K8s namespace
        K8S_NAMESPACE = 'default'
    }

    options {
        timestamps()
        skipDefaultCheckout(false)
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Unit Tests') {
            steps {
                script {
                    services.each { svc ->
                        dir("services/${svc}") {
                            sh """
                               echo "Running tests for ${svc}..."
                               if [ -f package.json ]; then
                                   npm install
                                   npm test
                               else
                                   echo "No package.json, skip npm test"
                               fi
                            """
                        }
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    withSonarQubeEnv('SonarQubeServer') {
                        // Lấy đường dẫn tới sonar-scanner mà Jenkins đã cài
                        def scannerHome = tool 'SonarScanner'
                        sh """
                           ${scannerHome}/bin/sonar-scanner \
                             -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                             -Dsonar.projectName=${SONAR_PROJECT_NAME} \
                             -Dsonar.projectVersion=${SONAR_PROJECT_VER} \
                             -Dsonar.sources=./services \
                             -Dsonar.host.url=$SONAR_HOST_URL \
                             -Dsonar.login=$SONAR_AUTH_TOKEN
                        """
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    // Lấy username/password từ credential docker-registry-cred
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-registry-cred',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {

                        // Debug: in ra user đang login (không in password)
                        sh '''
                           echo "Logging in to Docker as ${DOCKER_USER} ..."
                        '''

                        // Login an toàn bằng --password-stdin
                        sh """
                           echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        """

                        services.each { svc ->
                            def imageTag = "${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"
                            dir("services/${svc}") {
                                sh """
                                   echo "Building Docker image for ${svc}..."
                                   docker build -t ${imageTag} .

                                   echo "Pushing image ${imageTag}..."
                                   docker push ${imageTag}
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            when {
                expression { return true }
            }
            steps {
                script {
                    services.each { svc ->
                        def imageTag = "${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"
                        sh """
                           echo "Scanning image ${imageTag} with Trivy..."
                           trivy image --severity HIGH,CRITICAL --exit-code 0 ${imageTag}
                        """
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh """
                       echo "Deploying to Kubernetes namespace ${K8S_NAMESPACE}..."
                       kubectl apply -n ${K8S_NAMESPACE} -f k8s/
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed. Please check the stages above."
        }
    }
}
