# End-to-End DevOps CI/CD Automation Pipeline

**Project type:** Graduation project  
**Technology stack:** GitHub, Jenkins, Maven, SonarQube, Docker, Kubernetes, AWS  
**Application:** Java 21 Spring Boot REST service  
**Container registry:** GitHub Container Registry for the demonstration; ECR is a production alternative

## 1. Project Abstract & Architecture Overview

### Abstract

Modern software teams must deliver features quickly without sacrificing correctness, security, or service availability. Manual release processes make outcomes inconsistent and slow feedback expensive. This project implements a repeatable continuous integration and continuous delivery pipeline that turns each approved source change into a tested, analyzed, versioned container and controlled Kubernetes release with traceability. GitHub stores source and starts builds; Jenkins orchestrates stages; Maven compiles, tests, and packages the Spring Boot application; SonarQube evaluates maintainability and configured security rules; Docker creates an immutable image; Kubernetes schedules replicas and manages health; AWS provides elastic cloud infrastructure for an EKS deployment. Automated quality gates, least-privilege credentials, immutable image tags, health probes, and rollback-aware rollout status move defect detection earlier and make failures observable rather than manual surprises. The design separates application behavior from cluster-specific authentication and infrastructure settings, allowing the same container and mostly portable manifests to run on Minikube, Docker Desktop Kubernetes, or Amazon EKS. Local execution validates the developer workflow, while production adoption still requires appropriate IAM, networking, registry access, secrets management, monitoring, and environment-specific cluster configuration. By integrating these controls into versioned pipeline code, the project demonstrates reproducibility, traceability, and safer delivery practices for graduation projects and teams in practice.

### Architecture

```text
Developer
   | git push / pull request
   v
GitHub repository
   | source control and webhook trigger
   v
Jenkins pipeline
   |-- checkout source
   |-- Maven compile, unit test, package
   |-- SonarQube analysis and quality gate
   |-- Docker image build
   |-- GHCR image publication
   `-- kubectl apply and rollout verification
          |
          v
Kubernetes API
   |-- local: Minikube or Docker Desktop Kubernetes
   `-- cloud: Amazon EKS
          |
          v
Spring Boot service (2 replicas, health probes, NodePort)
```

### Component responsibilities

- **GitHub:** Source control, pull-request review, branch protection, and webhook event source.
- **Jenkins:** Pipeline orchestration, credentials integration, stage reporting, and deployment automation.
- **Maven:** Java dependency resolution, compilation, unit testing, packaging, and coverage instrumentation.
- **SonarQube:** Static code analysis, quality metrics, configured security rules, and quality-gate decisions.
- **Docker:** Creation of a portable runtime image from the packaged JAR.
- **Kubernetes:** Declarative application scheduling, replica management, health checks, service discovery, and rolling updates.
- **AWS:** Cloud infrastructure and Amazon EKS managed Kubernetes. IAM and networking remain AWS-specific.
- **GHCR:** Example image registry. It is used here so the same public image can be pulled by local Kubernetes and EKS.

## 2. Core Pipeline-as-Code

The declarative `Jenkinsfile` in the repository defines the build and release stages:

1. **Code Checkout:** Retrieves the revision selected by the Multibranch Pipeline.
2. **Configuration Validation:** Checks that the supplied image path is a valid GHCR repository.
3. **Maven Compile & Unit Testing:** Runs a clean test lifecycle and publishes JUnit test results.
4. **Maven Packaging:** Produces `target/app.jar` for the container build.
5. **SonarQube Static Analysis:** Submits Java source and JaCoCo coverage data for analysis.
6. **Quality Gate:** Stops the pipeline if the configured SonarQube quality gate does not pass.
7. **Docker Image Build:** Creates a unique tag from the Jenkins build number and Git commit SHA.
8. **Registry Publication:** On `main`, authenticates to GHCR using a Jenkins credential and pushes the versioned image.
9. **Kubernetes Deployment:** On `main`, renders the image reference into the manifest, applies it, and waits for rollout. A local kubeconfig or AWS-backed EKS kubeconfig is selected by the build parameter.
10. **Post-actions:** Publishes test results, reports build status, and removes the workspace.

The pipeline avoids embedding tokens in source. Jenkins credentials are injected only into the steps that need them. The example is suitable for a trusted lab; production should use isolated ephemeral build workers, protected branches, short-lived credentials, and a carefully scoped deployment identity.

## 3. Containerization & Orchestration Manifests

### Application

The sample Spring Boot service exposes `GET /api`, returning application name and status. Spring Boot Actuator exposes health endpoints used by Kubernetes startup, readiness, and liveness probes. The Maven project includes a MockMvc test and JaCoCo instrumentation.

### Container image

The Dockerfile uses an Eclipse Temurin Java 21 JRE runtime image, runs as UID/GID 10001, copies the Maven-built executable JAR, and configures the JVM to respect container memory limits. The image is built after Maven packaging, avoiding a second independent build inside Docker.

### Kubernetes resources

`k8s/deployment.yaml` defines:

- A project namespace.
- A two-replica Deployment with rolling updates and revision history.
- CPU and memory requests and limits.
- Startup, readiness, and liveness probes.
- A non-root security context, read-only root filesystem, dropped Linux capabilities, and a small writable temporary volume.
- A NodePort Service on port 30080.
- A PodDisruptionBudget that keeps at least one pod available during voluntary disruption.

The workload resources are portable Kubernetes APIs. A production service should normally use an ingress or cloud load balancer, TLS, and cluster-specific policies rather than exposing NodePort directly.

## 4. Architectural Design Justification: Local Simulation to AWS EKS

### Infrastructure as Code principles

The project stores build and deployment logic as version-controlled code. The Jenkinsfile describes repeatable pipeline actions, the Dockerfile declares how the runtime image is assembled, and Kubernetes YAML describes desired workload state. Review, history, reproducibility, and rollback are improved compared with manual, undocumented steps. Environment-specific parameters and credentials are kept outside application source.

This is a cloud-portable application deployment design, not complete provider-independent infrastructure provisioning. A full environment would separately define cluster, VPC, identity, DNS, TLS, registry, storage, and monitoring resources using an IaC tool such as Terraform or AWS CloudFormation.

### Local Kubernetes compared with EKS

Local clusters and EKS support Kubernetes workload APIs and can validate the main build-to-deploy flow. They are not architecturally identical. EKS includes a managed control plane, AWS IAM authentication, AWS networking and load-balancer integrations, and cloud worker-node lifecycle. Local clusters differ in networking, storage classes, identity, capacity, availability, and service exposure. Local validation is therefore useful but does not replace staging on EKS.

### Migration considerations

The application code and Dockerfile can remain unchanged when the runtime and image are the same. Standard Kubernetes objects can often be reused, but cluster access, networking, image pull authorization, service exposure, storage, and operational policy must be configured for EKS. EKS uses AWS IAM-backed authentication and authorization; migration is not simply replacing a static API token. A kubeconfig can be generated with AWS CLI, but the IAM identity must be authorized by the cluster and the deployment environment must have network access to the API.

The sample manifest uses NodePort and a public GHCR image to keep the educational example simple. Production may use ECR with EKS node IAM roles, a private package pull secret, ingress, TLS, and AWS-specific service annotations or separate environment overlays.

## 5. Virtual Step-by-Step Implementation Runbook

### Prerequisites

1. Install Docker Engine and Docker Compose, Git, Java 21, and `kubectl`.
2. Install Minikube or enable Docker Desktop Kubernetes.
3. Create a GitHub repository and push this project.
4. Prepare a GHCR token with package write access. Create a public package for the local demonstration, or configure image-pull authorization for a private package.
5. For EKS, prepare an existing cluster, AWS IAM identity, cluster access entry/RBAC authorization, and network path from Jenkins.

### Server setup

1. On a Linux host, set Elasticsearch's required virtual-memory setting for SonarQube:

   ```bash
   sudo sysctl -w vm.max_map_count=524288
   ```

2. Set the Docker socket group ID and start the local stack:

   ```bash
   export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
   docker compose up -d --build
   docker compose ps
   ```

3. Open Jenkins at `http://localhost:8080`, retrieve its first-run password, and install Pipeline, GitHub, SonarQube Scanner, Credentials Binding, AWS Credentials, Workspace Cleanup, and JUnit plugins.
4. Open SonarQube at `http://localhost:9000`, set an administrative password, create a project token, and configure the Jenkins server named `SonarQube` at `http://sonarqube:9000`.
5. Set SonarQube's Jenkins webhook to `http://jenkins:8080/sonarqube-webhook/`.
6. Add Jenkins credentials: `ghcr-package-publisher`, `local-kubeconfig`, and, for AWS deployments, `aws-deployer`.

### Pipeline execution

1. Start a local Kubernetes cluster, for example `minikube start`.
2. Create a Jenkins Multibranch Pipeline job for the GitHub repository and scan it.
3. Run the `main` branch with `IMAGE_REPOSITORY` set to a lowercase GHCR path, for example `ghcr.io/my-owner/end-to-end-devops-app`.
4. Select `DEPLOY_TARGET=local` and ensure the Jenkins kubeconfig endpoint is reachable from the Jenkins container.
5. Verify the workload and application response:

   ```bash
   kubectl get deployments,pods,services -n devops-demo
   ./scripts/verify-local.sh
   ```

6. For EKS, configure the `aws-deployer` credential and run `main` with `DEPLOY_TARGET=eks`, the existing EKS cluster name, and AWS region.
7. GitHub webhooks cannot reach a loopback-only Jenkins address. For a local test, use **Build Now**; for webhook testing, expose Jenkins through a secured HTTPS endpoint and configure a webhook secret.

### Expected verification

- Maven reports a passing unit test and the Jenkins JUnit result is visible.
- SonarQube analysis completes and the configured quality gate passes.
- Jenkins publishes a unique image tag to GHCR on `main`.
- Kubernetes reports two available replicas and a successful rollout.
- `GET /api` returns `{"application":"end-to-end-devops-app","status":"running"}`.

These are expected checks, not claimed execution results. Actual outcomes depend on the user's Jenkins, SonarQube, registry, and Kubernetes configuration.

## Security, limitations, and future improvements

- The local Compose setup mounts the host Docker socket into Jenkins. This grants broad host control and is strictly for trusted local lab use. Replace it with ephemeral isolated agents for production.
- Public images are convenient for local testing but unsuitable for confidential application images. Use private registry access and least-privilege image-pull identity in production.
- SonarQube security detection depends on installed edition, language analyzers, and quality profile. It complements, but does not replace, dependency scanning, secret scanning, container scanning, and dynamic testing.
- NodePort is an educational exposure choice. Production should use approved ingress/load-balancer patterns, TLS, network restrictions, observability, backup, and recovery procedures.
- Future work can add Terraform or CloudFormation for repeatable AWS infrastructure, ECR publishing, vulnerability scanning, SBOM generation, policy-as-code, deployment approvals, and automated rollback.

## References

- Jenkins Pipeline documentation: https://www.jenkins.io/doc/book/pipeline/
- Apache Maven guides: https://maven.apache.org/guides/
- SonarQube documentation: https://docs.sonarsource.com/sonarqube-server/
- Docker build documentation: https://docs.docker.com/build/
- Kubernetes concepts: https://kubernetes.io/docs/concepts/
- Amazon EKS user guide: https://docs.aws.amazon.com/eks/latest/userguide/
