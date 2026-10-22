
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['VALIDATE_ONLY', 'DEPLOY_STABLE', 'TEST_FAULTY_ROLLBACK'],
            description: 'Choose validation, stable deployment, or automatic rollback demonstration'
        )
    }

    environment {
        IMAGE_NAME = 'abhinesh18g/traffic-management-system'
        DEPLOYMENT_NAME = 'traffic-management'
        CONTAINER_NAME = 'traffic-dashboard'
        SERVICE_NAME = 'traffic-management-service'
    }

    stages {
        stage('Checkout Latest Source') {
            steps {
                checkout scm
                bat 'git log -1 --oneline'
            }
        }

        stage('Parallel Automated Tests') {
            parallel {
                stage('Dashboard Tests') {
                    steps {
                        bat 'if not exist index.html exit /b 1'
                        bat 'findstr /C:"INT-01" /C:"INT-05" index.html'
                        bat 'findstr /C:"waiting>120" /C:"waiting > 120" index.html'
                        bat 'findstr /C:"diversion" /C:"Diversion" index.html'
                        echo 'Dashboard source checks passed.'
                    }
                }

                stage('Infrastructure Tests') {
                    steps {
                        bat 'if not exist Dockerfile exit /b 1'
                        bat 'if not exist deployment.yaml exit /b 1'
                        bat 'findstr /C:"kind: Deployment" deployment.yaml'
                        bat 'findstr /C:"readinessProbe" deployment.yaml'
                        bat 'findstr /C:"kind: Service" deployment.yaml'
                        echo 'Infrastructure source checks passed.'
                    }
                }
            }
        }

        stage('Archive Source Artifacts') {
            steps {
                archiveArtifacts artifacts: 'index.html,Dockerfile,deployment.yaml,Jenkinsfile',
                                 fingerprint: true
            }
        }

        stage('Docker Build and Push') {
            when {
                expression { params.ACTION != 'VALIDATE_ONLY' }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat 'docker build --build-arg CREATE_HEALTH_PAGE=true -t %IMAGE_NAME%:v1 -t %IMAGE_NAME%:build-%BUILD_NUMBER% .'
                    bat 'docker image inspect %IMAGE_NAME%:v1'
                    bat 'echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin'
                    bat 'docker push %IMAGE_NAME%:v1'
                    bat 'docker push %IMAGE_NAME%:build-%BUILD_NUMBER%'
                    bat 'docker logout'
                }
            }
        }

        stage('Deploy Stable Release') {
            when {
                expression {
                    params.ACTION == 'DEPLOY_STABLE' ||
                    params.ACTION == 'TEST_FAULTY_ROLLBACK'
                }
            }
            steps {
                withCredentials([
                    file(credentialsId: 'kuberconfig', variable: 'KUBECONFIG')
                ]) {
                    bat 'kubectl config current-context'
                    bat 'kubectl apply -f deployment.yaml'
                    bat 'kubectl set image deployment/%DEPLOYMENT_NAME% %CONTAINER_NAME%=%IMAGE_NAME%:v1'
                    bat 'kubectl rollout status deployment/%DEPLOYMENT_NAME% --timeout=120s'
                    bat 'kubectl get deployment %DEPLOYMENT_NAME%'
                    bat 'kubectl get pods -l app=traffic-management'
                    bat 'kubectl get service %SERVICE_NAME%'
                }
            }
        }

        stage('Test Faulty Release and Roll Back') {
            when {
                expression { params.ACTION == 'TEST_FAULTY_ROLLBACK' }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    ),
                    file(credentialsId: 'kuberconfig', variable: 'KUBECONFIG')
                ]) {
                    script {
                        def faultyTag = "faulty-${env.BUILD_NUMBER}"
                        def rolloutFailed = false

                        bat "docker build --build-arg CREATE_HEALTH_PAGE=false -t ${env.IMAGE_NAME}:${faultyTag} ."

                        bat "echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin"
                        bat "docker push ${env.IMAGE_NAME}:${faultyTag}"
                        bat 'docker logout'

                        echo "Deploying deliberately faulty image: ${env.IMAGE_NAME}:${faultyTag}"

                        bat "kubectl set image deployment/${env.DEPLOYMENT_NAME} ${env.CONTAINER_NAME}=${env.IMAGE_NAME}:${faultyTag}"

                        try {
                            bat "kubectl rollout status deployment/${env.DEPLOYMENT_NAME} --timeout=90s"
                        } catch (Exception err) {
                            rolloutFailed = true
                            echo 'EXPECTED FAILURE: Faulty release did not become ready.'
                            bat 'kubectl get pods -l app=traffic-management'
                            bat 'kubectl describe deployment traffic-management'
                        }

                        if (!rolloutFailed) {
                            error('Fault injection failed: the faulty rollout unexpectedly succeeded.')
                        }

                        echo 'Automatically restoring the previous stable release.'
                        bat 'kubectl rollout undo deployment/traffic-management'
                        bat 'kubectl rollout status deployment/traffic-management --timeout=120s'

                        def activeImage = bat(
                            script: 'kubectl get deployment traffic-management -o jsonpath={.spec.template.spec.containers[0].image}',
                            returnStdout: true
                        ).trim()

                        echo "Image after rollback: ${activeImage}"

                        if (activeImage != "${env.IMAGE_NAME}:v1") {
                            error("Rollback verification failed. Unexpected image: ${activeImage}")
                        }

                        bat 'kubectl get deployment traffic-management'
                        bat 'kubectl get pods -l app=traffic-management'
                        bat 'kubectl get service traffic-management-service'

                        echo 'Rollback verification passed: stable v1 is restored.'
                    }
                }
            }
        }

        stage('Final Verification') {
            when {
                expression { params.ACTION != 'VALIDATE_ONLY' }
            }
            steps {
                withCredentials([
                    file(credentialsId: 'kuberconfig', variable: 'KUBECONFIG')
                ]) {
                    bat 'kubectl rollout status deployment/traffic-management --timeout=120s'
                    bat 'kubectl get deployment traffic-management'
                    bat 'kubectl get pods -l app=traffic-management'
                    bat 'kubectl get service traffic-management-service'
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Inspect Console Output and the failed stage.'
        }
        always {
            echo 'Traffic Management CI/CD pipeline finished.'
        }
    }
}
