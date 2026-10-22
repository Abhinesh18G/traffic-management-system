pipeline {
    agent any

    parameters {
        choice(
            name: 'RELEASE_MODE',
            choices: ['STABLE', 'FAULTY'],
            description: 'Choose STABLE for a normal deployment or FAULTY to test automatic rollback.'
        )
    }

    environment {
        DOCKER_IMAGE = "abhinesh18g/traffic-management-dashboard"
        IMAGE_TAG = "v1"
        FAULTY_BUILD = "false"
    }

    stages {

        stage('Clone Code') {
            steps {
                checkout scm
            }
        }

        stage('Prepare Release') {
            steps {
                script {
                    if (params.RELEASE_MODE == 'FAULTY') {
                        env.IMAGE_TAG = 'faulty'
                        env.FAULTY_BUILD = 'true'
                        echo 'Preparing deliberately faulty release.'
                    } else {
                        env.IMAGE_TAG = 'v1'
                        env.FAULTY_BUILD = 'false'
                        echo 'Preparing stable release.'
                    }
                }
            }
        }

        stage('Parallel Validation') {
            parallel {

                stage('Validate Dashboard') {
                    steps {
                        bat 'findstr /C:"Traffic Management Dashboard" index.html'
                        bat 'findstr /C:"Emergency Vehicle Priority" index.html'
                        bat 'findstr /C:"Traffic Diversion" index.html'
                    }
                }

                stage('Validate Project Files') {
                    steps {
                        bat 'if exist Dockerfile (echo Dockerfile found) else (exit /b 1)'
                        bat 'if exist deployment.yaml (echo deployment.yaml found) else (exit /b 1)'
                        bat 'if exist Jenkinsfile (echo Jenkinsfile found) else (exit /b 1)'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build --build-arg FAULTY=%FAULTY_BUILD% -t %DOCKER_IMAGE%:%IMAGE_TAG% .'
            }
        }

        stage('Test Application') {
            steps {
                bat 'docker image inspect %DOCKER_IMAGE%:%IMAGE_TAG%'
                bat 'docker run --rm %DOCKER_IMAGE%:%IMAGE_TAG% nginx -t'
                bat 'docker run --rm %DOCKER_IMAGE%:%IMAGE_TAG% sh -c "test -s /usr/share/nginx/html/index.html"'
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts(
                    artifacts: 'index.html,Dockerfile,deployment.yaml,Jenkinsfile',
                    fingerprint: true
                )
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat 'echo %DOCKER_PASS%| docker login -u %DOCKER_USER% --password-stdin'
                    bat 'docker push %DOCKER_IMAGE%:%IMAGE_TAG%'
                }
            }
        }

        stage('Deploy and Verify') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    script {
                        if (params.RELEASE_MODE == 'STABLE') {

                            bat 'kubectl apply -f deployment.yaml --validate=false'

                            bat 'kubectl rollout status deployment/traffic-dashboard --timeout=120s'

                            echo 'Stable deployment completed successfully.'

                        } else {

                            echo 'Attempting to deploy deliberately faulty image.'

                            bat 'kubectl set image deployment/traffic-dashboard traffic-dashboard=%DOCKER_IMAGE%:%IMAGE_TAG%'

                            try {

                                bat 'kubectl rollout status deployment/traffic-dashboard --timeout=70s'

                                error('The faulty rollout unexpectedly succeeded. Check the readiness probe and Dockerfile.')

                            } catch (err) {

                                echo 'Faulty rollout failed as expected. Starting automatic rollback.'

                                bat 'kubectl rollout undo deployment/traffic-dashboard'

                                bat 'kubectl rollout status deployment/traffic-dashboard --timeout=120s'

                                echo 'Automatic rollback completed. The previous stable release has been restored.'
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Traffic dashboard pipeline execution finished.'
        }

        success {
            echo 'Pipeline completed. Check the console output and Kubernetes status.'
        }

        failure {
            echo 'Pipeline failed. Inspect Console Output for the failing stage.'
        }
    }
}