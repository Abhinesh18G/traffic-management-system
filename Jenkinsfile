
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Initial Source Validation') {
            steps {
                bat 'git --version'
                bat 'if not exist index.html exit /b 1'
                bat 'if not exist Dockerfile exit /b 1'
                bat 'if not exist deployment.yaml exit /b 1'
                echo 'Initial source files are present.'
            }
        }
    }
}
