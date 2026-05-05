pipeline {

	agent { label "${params.BUILD_LOCATION == 'master' ? 'built-in || master' : 'build-agent'}" }


```
environment {
    BUILD_SCRIPT = "scripts/build_open5gs.sh"
    ARTIFACT_NAME = "open5gs-build.tar.gz"
}

options {
    timestamps()
}

stages {

    stage('Checkout') {
        steps {
            script {
                def branch = env.CHANGE_BRANCH ?: env.BRANCH_NAME ?: 'main'
                def branchSpec = branch.startsWith('refs/') ? branch : "*/${branch}"

                checkout([$class: 'GitSCM',
                    branches: [[name: branchSpec]],
                    userRemoteConfigs: [[url: 'https://github.com/open5gs/open5gs.git']]
                ])
            }
        }
    }

    stage('Prepare Script') {
        steps {
            sh '''
            mkdir -p scripts
            chmod +x scripts/build_open5gs.sh || true
            '''
        }
    }

    stage('Build & Test') {
        steps {
            sh '''
            chmod +x ${BUILD_SCRIPT}
            ${BUILD_SCRIPT}
            '''
        }
    }

    stage('Package Artifact') {
        steps {
            sh '''
            tar -czf ${ARTIFACT_NAME} install/
            '''
        }
    }

    stage('Archive') {
        steps {
            archiveArtifacts artifacts: "${ARTIFACT_NAME}", fingerprint: true
        }
    }
}

post {
    success {
        echo "✅ Open5GS CI pipeline successful"
    }
    failure {
        echo "❌ Build failed"
    }
}
```

}

