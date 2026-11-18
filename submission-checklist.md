# Submission checklist

- [ ] Replace the sample GitHub owner in Jenkins build parameters with the actual GHCR image path.
- [ ] Create Jenkins credentials with the IDs documented in `README.md`.
- [ ] Confirm SonarQube server and webhook configuration.
- [ ] Confirm the local kubeconfig endpoint is reachable from the Jenkins container, or configure EKS IAM authorization.
- [ ] Push the project to the student's GitHub repository and include the commit URL in the final submission.
- [ ] Run Maven tests and retain the Jenkins test and SonarQube quality-gate results as evidence.
- [ ] Capture screenshots of the successful Jenkins stages, SonarQube result, Kubernetes pods/services, and `/api` response.
- [ ] Replace local-only passwords and review registry visibility before any production deployment.
- [ ] Add student name, institution, course, supervisor, and submission date to the cover page if required by the university.
