pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        timeout(time: 40, unit: 'MINUTES')
    }

    parameters {
        choice(
            name: 'DEPLOY_TARGET',
            choices: ['local', 'eks'],
            description: 'Deploy to a configured local Kubernetes cluster or Amazon EKS'
        )
        string(
            name: 'IMAGE_REPOSITORY',
            defaultValue: '',
            description: 'Required GHCR path, for example ghcr.io/my-owner/end-to-end-devops-app'
        )
        string(
            name: 'AWS_REGION',
            defaultValue: 'us-east-1',
            description: 'AWS region used for EKS deployment'
        )
        string(
            name: 'EKS_CLUSTER_NAME',
            defaultValue: 'graduation-project-eks',
            description: 'Existing EKS cluster name when DEPLOY_TARGET is eks'
        )
    }

    environment {
        SONARQUBE_SERVER = 'SonarQube'
        SONAR_PROJECT_KEY = 'end-to-end-devops-app'
        GHCR_CREDENTIALS_ID = 'ghcr-package-publisher'
        LOCAL_KUBECONFIG_CREDENTIALS_ID = 'local-kubeconfig'
        AWS_CREDENTIALS_ID = 'aws-deployer'
        K8S_NAMESPACE = 'devops-demo'
    }

    stages {
        stage('Code Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Configuration') {
            steps {
                script {
                    def imageRepository = params.IMAGE_REPOSITORY.trim().toLowerCase()
                    if (!(imageRepository ==~ /ghcr\.io\/[a-z0-9][a-z0-9-]*\/[a-z0-9._-]+/)) {
                        error 'IMAGE_REPOSITORY must be a valid lowercase GHCR path: ghcr.io/owner/repository'
                    }
                    env.GHCR_IMAGE = imageRepository
                }
            }
        }

        stage('Maven Compile & Unit Testing') {
            steps {
                sh 'mvn -B -ntp clean test'
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                }
            }
        }

        stage('Maven Packaging') {
            steps {
                sh 'mvn -B -ntp package -DskipTests'
            }
        }

        stage('SonarQube Static Analysis') {
            steps {
                withSonarQubeEnv(env.SONARQUBE_SERVER) {
                    sh '''
                        mvn -B -ntp \
                          org.jacoco:jacoco-maven-plugin:0.8.12:report \
                          org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar \
                          -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
                          -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
                    '''
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        def qualityGate = waitForQualityGate()
                        if (qualityGate.status != 'OK') {
                            error "SonarQube quality gate failed: ${qualityGate.status}"
                        }
                    }
                }
            }
        }

        stage('Docker Container Image Build') {
            steps {
                script {
                    env.GIT_SHA = sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_SHA}"
                    env.FULL_IMAGE = "${env.GHCR_IMAGE}:${env.IMAGE_TAG}"
                }
                sh 'docker build --pull --tag "$FULL_IMAGE" .'
            }
        }

        stage('Publishing to Container Registry') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: env.GHCR_CREDENTIALS_ID,
                        usernameVariable: 'GHCR_USER',
                        passwordVariable: 'GHCR_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
                        printf '%s' "$GHCR_TOKEN" |
                          docker login ghcr.io --username "$GHCR_USER" --password-stdin
                        docker push "$FULL_IMAGE"
                    '''
                }
            }
        }

        stage('Continuous Deployment to Kubernetes') {
            when {
                branch 'main'
            }
            steps {
                script {
                    if (params.DEPLOY_TARGET == 'eks') {
                        withCredentials([[
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: env.AWS_CREDENTIALS_ID
                        ]]) {
                            sh '''
                                set -eu
                                mkdir -p "$WORKSPACE/.kube"
                                export KUBECONFIG="$WORKSPACE/.kube/config"
                                aws eks update-kubeconfig \
                                  --name "$EKS_CLUSTER_NAME" \
                                  --region "$AWS_REGION" \
                                  --kubeconfig "$KUBECONFIG"
                                sed "s|__IMAGE__|$FULL_IMAGE|g" \
                                  k8s/deployment.yaml > "$WORKSPACE/rendered-k8s.yaml"
                                kubectl apply -f "$WORKSPACE/rendered-k8s.yaml"
                                kubectl rollout status \
                                  deployment/end-to-end-devops-app \
                                  --namespace "$K8S_NAMESPACE" \
                                  --timeout=180s
                            '''
                        }
                    } else {
                        withCredentials([file(
                            credentialsId: env.LOCAL_KUBECONFIG_CREDENTIALS_ID,
                            variable: 'KUBECONFIG_FILE'
                        )]) {
                            sh '''
                                set -eu
                                export KUBECONFIG="$KUBECONFIG_FILE"
                                sed "s|__IMAGE__|$FULL_IMAGE|g" \
                                  k8s/deployment.yaml > "$WORKSPACE/rendered-k8s.yaml"
                                kubectl apply -f "$WORKSPACE/rendered-k8s.yaml"
                                kubectl rollout status \
                                  deployment/end-to-end-devops-app \
                                  --namespace "$K8S_NAMESPACE" \
                                  --timeout=180s
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs(deleteDirs: true, disableDeferredWipeout: true)
        }
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review stage logs and the quality gate result.'
        }
    }
}
