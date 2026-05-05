pipeline {

    agent {
        label "${params.BUILD_LOCATION == 'master' ? 'built-in || master' : 'build-agent'}"
    }

    environment {
        BUILD_SCRIPT        = "scripts/build_open5gs.sh"
        ARTIFACT_NAME       = "open5gs-build.tar.gz"
        REPO_URL            = "https://github.com/sambitcom/open5gs_Devop_training.git"
        REPO_URL_SSH        = "git@github.com:sambitcom/open5gs_Devop_training.git"
        GIT_CREDENTIALS     = "open5g"
        GIT_CREDENTIALS_SSH = "github-ssh-key"
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
                    def branch     = env.CHANGE_BRANCH ?: env.BRANCH_NAME ?: 'main'
                    def branchSpec = branch.startsWith('refs/') ? branch : "*/${branch}"
                    def checkedOut = false

                    // --- Primary: HTTPS with 10-minute timeout ---
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            checkout([$class: 'GitSCM',
                                branches: [[name: branchSpec]],
                                doGenerateSubmoduleConfigurations: false,
                                extensions: [
                                    [$class: 'CleanBeforeCheckout'],
                                    [$class: 'CloneOption', depth: 1, shallow: true, noTags: false]
                                ],
                                userRemoteConfigs: [[
                                    url:           "${REPO_URL}",
                                    credentialsId: "${GIT_CREDENTIALS}"
                                ]]
                            ])
                        }
                        checkedOut = true
                        echo "✅ Checkout via HTTPS succeeded"
                    } catch (Exception e) {
                        echo "⚠️  HTTPS checkout failed or timed out after 10 min: ${e.message}"
                        echo "🔄 Falling back to SSH checkout..."
                    }

                    // --- Fallback: SSH ---
                    if (!checkedOut) {
                        sshagent(credentials: ["${GIT_CREDENTIALS_SSH}"]) {
                            checkout([$class: 'GitSCM',
                                branches: [[name: branchSpec]],
                                doGenerateSubmoduleConfigurations: false,
                                extensions: [
                                    [$class: 'CleanBeforeCheckout'],
                                    [$class: 'CloneOption', depth: 1, shallow: true, noTags: false]
                                ],
                                userRemoteConfigs: [[
                                    url:           "${REPO_URL_SSH}",
                                    credentialsId: "${GIT_CREDENTIALS_SSH}"
                                ]]
                            ])
                        }
                        echo "✅ Checkout via SSH succeeded"
                    }
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
