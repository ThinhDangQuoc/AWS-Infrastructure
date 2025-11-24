def services = ['orders', 'payments', 'users']

pipeline {
    agent any

    environment {
        // Docker registry
        DOCKER_REGISTRY = 'docker.io/quannha5'

        // SonarQube
        SONARQUBE_ENV      = 'SonarQubeServer'
        SONAR_PROJECT_KEY  = 'microservices-monorepo'
        SONAR_PROJECT_NAME = 'microservices-monorepo'
        SONAR_PROJECT_VER  = '1.0'
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
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-registry-cred',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {

                        sh '''
                           echo "Logging in to Docker as ${DOCKER_USER} ..."
                        '''

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
            steps {
                script {
                    services.each { svc ->
                        def imageTag = "${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"
                        sh """
                           echo "Scanning image ${imageTag} with Trivy (Docker)..."
                           docker run --rm \
                             -v /var/run/docker.sock:/var/run/docker.sock \
                             aquasec/trivy:latest \
                             image --severity HIGH,CRITICAL --exit-code 0 ${imageTag}
                        """
                    }
                }
            }
        }

        stage('Deploy to Docker') {
            steps {
                script {
                    services.each { svc ->
                        def imageTag = "${DOCKER_REGISTRY}/${svc}:${env.BUILD_NUMBER}"

                        // ⚠️ Chỗ này bạn chỉnh port cho đúng từng service
                        def portMapping = ""
                        if (svc == "orders") {
                            portMapping = "-p 8081:8080"
                        } else if (svc == "payments") {
                            portMapping = "-p 8082:8080"
                        } else if (svc == "users") {
                            portMapping = "-p 8083:8080"
                        }

                        sh """
                           echo "Deploying ${svc} using Docker image ${imageTag}..."

                           # Kéo image (phòng khi deploy trên node khác)
                           docker pull ${imageTag} || true

                           # Dừng container cũ nếu có
                           docker stop ${svc} || true
                           docker rm ${svc} || true

                           # Chạy container mới
                           docker run -d --name ${svc} \\
                             --restart=always \\
                             ${portMapping} \\
                             ${imageTag}
                        """
                    }
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
