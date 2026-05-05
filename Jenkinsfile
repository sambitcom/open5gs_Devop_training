pipeline {

    agent { 
        label "${params.BUILD_LOCATION == 'master' ? 'built-in || master' : 'build-agent'}" 
    }

    environment {
        BUILD_SCRIPT = "scripts/build_open5gs.sh"
        ARTIFACT_NAME = "open5gs-build.tar.gz"
        REPO_URL = "https://github.com/sambitcom/open5gs_Devop_training.git"
        GIT_CREDENTIALS = "open5g"
    }

    options {
        timestamps()
        skipDefaultCheckout()
    }

    parameters {
        choice(
            name: 'BUILD_LOCATION',
            choices: ['master', 'agent'],
            description: 'Select where to run the build'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                script {
                    def branch = env.CHANGE_BRANCH ?: env.BRANCH_NAME ?: 'main'
                    def branchSpec = branch.startsWith('refs/') ? branch : "*/${branch}"

                    checkout([$class: 'GitSCM',
                        branches: [[name: branchSpec]],
                        doGenerateSubmoduleConfigurations: false,
                        extensions: [
                            [$class: 'CleanBeforeCheckout'],   // clean workspace
                            [$class: 'CloneOption', depth: 1, shallow: true, noTags: false]
                        ],
                        userRemoteConfigs: [[
                            url: "${REPO_URL}",
                            credentialsId: "${GIT_CREDENTIALS}"
                        ]]
                    ])
                }
            }
        }

        stage('Setup Python Env') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip setuptools wheel
                '''
            }
        }

        stage('Build Open5GS') {
            steps {
                sh '''
                    chmod +x ${BUILD_SCRIPT}
                    ${BUILD_SCRIPT}
                '''
            }
        }

        stage('Archive Artifact') {
            steps {
                sh '''
                    tar -czf ${ARTIFACT_NAME} .
                '''
                archiveArtifacts artifacts: "${ARTIFACT_NAME}", fingerprint: true
            }
        }
    }

    post {
        success {
            echo "✅ Build completed successfully"
        }
        failure {
            echo "❌ Build failed"
        }
        always {
            cleanWs()
        }
    }
}
