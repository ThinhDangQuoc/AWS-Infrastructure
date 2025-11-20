# AWS-Infrastructure

IaC playground that covers three delivery tracks required by the assignment:

1. **Terraform + GitHub Actions** – reusable modules for VPC, EC2, and security groups plus CI that runs `fmt`, `validate`, `plan`, and Checkov before applying.
2. **CloudFormation + CodePipeline** – nested templates for the same stack, validated through CodeBuild (cfn-lint + Taskcat) and promoted with CodePipeline from CodeCommit.
3. **Microservices CI/CD with Jenkins** – a declarative pipeline that builds/tests Dockerized services, enforces SonarQube quality gates, scans with Trivy, and deploys to Kubernetes.

---

## 1. Terraform workflow (GitHub Actions)
- Source lives under `terraform/` with discrete modules in `terraform/modules/*`.
- `.github/workflows/terraform-ci.yml` runs on `push`/`pull_request` to `main` and performs:
  - `terraform fmt`, `init`, `validate`, `plan`, and exports the plan JSON.
  - Checkov IaC scanning on the `terraform` directory.
- `.github/workflows/deploy.yml` can be triggered manually to `terraform apply -auto-approve` once the CI plan is reviewed.
- Update the OIDC role ARN placeholders with your AWS account information.

## 2. CloudFormation workflow (CodeBuild + CodePipeline)
- Nested templates live in `cloudformation/main.yaml` and `cloudformation/modules/*.yml` covering VPC, routing, NAT Gateway, EC2, and security groups.
- `taskcat.yml` drives end-to-end testing by launching short-lived stacks from the packaged template.
- `buildspecs/cloudformation-validate.yml` (used by CodeBuild) performs:
  1. `cfn-lint` across all templates.
  2. `aws cloudformation package` to rewrite nested TemplateURLs.
  3. Taskcat tests against `packaged-template.yaml`.
- `cloudformation/codepipeline.yaml` declares:
  - An artifact bucket.
  - CodeBuild project wired to the buildspec above.
  - A multi-stage CodePipeline (CodeCommit ➜ CodeBuild ➜ CloudFormation deploy).
- Deploy the pipeline stack with:
  ```bash
  aws cloudformation deploy \
    --template-file cloudformation/codepipeline.yaml \
    --stack-name aws-infra-pipeline \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameter-overrides CodeCommitRepositoryName=<repo> CodeCommitBranch=main CloudFormationStackName=aws-infrastructure
  ```
- CodeBuild expects the environment variable `PACKAGE_BUCKET` (populated by the template) to upload nested templates during the packaging phase.

## 3. Microservices CI/CD with Jenkins
- `Jenkinsfile` orchestrates the microservices workflow:
  - Installs dependencies and runs tests for each service under `services/<name>`.
  - Executes SonarQube analysis (`withSonarQubeEnv('SonarQubeServer')`) and waits for the quality gate.
  - Builds/pushes Docker images (tagged with the Jenkins build number and `latest`) to the configured ECR registry.
  - Runs Trivy (`--severity HIGH,CRITICAL`) to gate on container/file-system vulnerabilities.
  - Deploys to Kubernetes using manifests/overlays stored in `k8s/`.
- Sample services (`services/orders`, `services/payments`, `services/users`) are lightweight Express APIs with unit tests (Node test runner + Supertest) and their own Dockerfiles so the Jenkins `docker build` stage has concrete artifacts to package.
- Kubernetes manifests live under `k8s/base` (Deployments + Services) with a production overlay in `k8s/overlays/prod` that Kustomize applies (`kubectl apply -k k8s/overlays/prod`). Update the image references or overlay patches if you change the registry/namespace naming conventions.
- Required Jenkins credentials/tools:
  - AWS credentials with ECR + EKS permissions (`aws-ecr-creds` in the sample).
  - SonarQube server named `SonarQubeServer`.
  - `kubeconfig` credential ID for cluster access.
  - Docker and Trivy CLIs available on the agents (add Snyk stage similarly if desired).

## 4. Local testing tips
- Run `terraform fmt -check` and `terraform validate` before opening PRs.
- Validate CloudFormation locally:
  ```bash
  cfn-lint cloudformation/main.yaml cloudformation/modules/*.yml
  aws cloudformation package --template-file cloudformation/main.yaml --s3-bucket <bucket> --output-template-file packaged-template.yaml
  taskcat test run -c taskcat.yml
  ```
- Execute the Jenkins pipeline stages individually with `jenkinsfile-runner` or a multibranch job when iterating on microservice changes.
