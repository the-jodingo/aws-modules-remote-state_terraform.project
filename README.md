# AWS Modules with Remote State

[![Terraform](https://github.com/the-jodingo/aws-modules-remote-state_terraform.project/actions/workflows/terraform.yml/badge.svg)](https://github.com/the-jodingo/aws-modules-remote-state_terraform.project/actions/workflows/terraform.yml)

A hands-on lab for writing reusable Terraform modules and storing state remotely. You will
build a small module library, create an S3 + DynamoDB backend, and wire the modules together
in an environment root.

**Who this is for:** students who can read basic HCL and have used the AWS console, but have
not yet built a module library or configured a remote backend.

**Time:** roughly 90 minutes if you follow it start to finish.

---

## What you will build

```
bootstrap/                Creates the state bucket, KMS key, and lock table
modules/vpc/              VPC, public and private subnets, NAT, route tables, flow logs
modules/s3-bucket/        Encrypted, versioned bucket with public access blocked
modules/security-group/   Security group driven by rule lists
environments/dev/         Root module that consumes all three modules
```

The point of the exercise is composition. Nothing inside `modules/` knows about any
environment, account, or region. Everything environment-specific is a variable supplied by
the caller.

---

## Learning objectives

By the end you should be able to:

1. Explain why local state files are unsafe for team work
2. Create an S3 backend with encryption and DynamoDB locking
3. Write a module with typed, documented input variables and outputs
4. Compose several modules inside an environment root
5. Validate and format a whole repository from the command line

---

## Prerequisites

| Tool | Version | Check |
| --- | --- | --- |
| Terraform | >= 1.5 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| AWS account | with IAM + VPC permissions | `aws sts get-caller-identity` |

Install the AWS CLI if you do not have it:

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

Configure credentials and confirm they work:

```bash
aws configure
# AWS Access Key ID:     <your key>
# AWS Secret Access Key: <your secret>
# Default region name:   us-east-1
# Default output format: json

aws sts get-caller-identity
```

You should see your account ID and ARN. If this fails, stop and fix it — nothing below will
work without working credentials.

---

## Step 1 — Create the remote backend

Local state is a single file on one laptop. Two people running `terraform apply` at the same
time will corrupt it, and losing the file means losing track of everything you built. The
`bootstrap/` root solves both problems.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and set a **globally unique** bucket name. S3 bucket names are unique
across all AWS accounts worldwide, so add your name or account ID:

```hcl
state_bucket_name = "tfstate-joash-2026-01"
```

Then run it. This root uses local state, which is fine — it only creates the backend, so the
state file is small and you will not re-run it often.

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. You should see roughly 8 resources created: the bucket, versioning,
encryption, public access block, ownership controls, lifecycle policy, bucket policy, KMS key
and alias, and the DynamoDB table.

Read the backend configuration it produced:

```bash
terraform output backend_config
```

Copy that output somewhere — you need the bucket and table names in the next step.

> **Note:** `bootstrap/` is deliberately not stored in the remote backend. If you stored the
> backend's own state inside the backend, destroying the backend would destroy the record of
> itself.

---

## Step 2 — Point the dev environment at the backend

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set a unique bucket name for the artifacts bucket:

```hcl
artifacts_bucket_name = "artifacts-joash-2026-01"
```

Now edit `backend/dev.hcl` and paste in the bucket name from Step 1:

```hcl
bucket         = "tfstate-joash-2026-01"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
```

The backend block in `main.tf` is empty on purpose:

```hcl
backend "s3" {}
```

Backend configuration cannot use variables, so the values arrive at init time via
`-backend-config`. That is what lets the same root target different environments without any
code change.

Initialize with the backend file:

```bash
terraform init -backend-config=backend/dev.hcl
```

Terraform should print `Successfully configured the backend "s3"!`

---

## Step 3 — Validate and inspect

Formatting is a hard requirement in this repository — CI fails on unformatted files, so get
into the habit locally:

```bash
terraform fmt -check -recursive -diff
```

If it reports files, fix them automatically:

```bash
terraform fmt -recursive
```

Validate every root and module in one pass:

```bash
cd ../..
for dir in bootstrap modules/* environments/*; do
  if [ -d "$dir" ] && ls "$dir"/*.tf >/dev/null 2>&1; then
    echo "==> $dir"
    terraform -chdir="$dir" init -backend=false -input=false
    terraform -chdir="$dir" validate
  fi
done
```

Every directory should report `Success! The configuration is valid.`

The `-backend=false` flag is what makes this safe to run in CI: no credentials, no state
access, just syntax and reference checking.

---

## Step 4 — Plan and apply

```bash
cd environments/dev
terraform plan
```

Read the plan before applying. Check specifically:

- the VPC CIDR matches what you set in `terraform.tfvars`
- two public and two private subnets are created, in different availability zones
- the NAT gateway count is 1 (because `single_nat_gateway = true`)

```bash
terraform apply
```

Then inspect what you built:

```bash
terraform output
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=platform" \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' --output table
```

---

## Step 5 — Understand the module contracts

Every module takes a `tags` map and merges it onto everything it creates:

```hcl
tags = local.common_tags
```

This keeps tagging policy with the caller rather than hard-coded inside the module. When your
organisation adds a `CostCenter` tag, you change one `locals` block, not three modules.

`modules/vpc` validates its `az_count` input:

```hcl
validation {
  condition     = var.az_count >= 1 && var.az_count <= 3
  error_message = "az_count must be between 1 and 3."
}
```

Try breaking it to see the validation fire:

```bash
terraform plan -var="az_count=5"
```

`modules/security-group` takes rule lists instead of individual arguments:

```hcl
ingress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.20.0.0/16"]
    description = "HTTPS from inside the VPC"
  },
]
```

> **Gotcha:** these rule sets are keyed by list index. Inserting a rule in the middle of the
> list changes the index of every rule after it, so Terraform destroys and recreates them.
> Always append new rules to the end.

---

## Step 6 — Clean up

NAT gateways bill by the hour. Destroy the environment when you are done for the day:

```bash
cd environments/dev
terraform destroy
```

The state bucket and lock table cost almost nothing and should be kept so you can rebuild
quickly. To remove them as well:

```bash
cd ../../bootstrap
terraform destroy
```

If the bucket refuses to delete, it still holds state objects. Either empty it manually or set
`force_destroy = true` in `terraform.tfvars` and apply again.

---

## Cost warning

Two resources here cost real money if left running:

| Resource | Approximate cost | Notes |
| --- | --- | --- |
| NAT gateway | ~$0.045/hour plus data | The main cost driver |
| S3 storage | pennies | Negligible at lab scale |
| DynamoDB | free tier | On-demand, tiny usage |
| CloudWatch Logs | pennies | Flow logs, 30-day retention |

A NAT gateway left running for a month is roughly $32. Set `enable_nat_gateway = false` if you
only want to practise the networking layout without egress.

---

## Troubleshooting

**`Error: error creating S3 Bucket: BucketAlreadyExists`**
Bucket names are global. Pick a more specific name.

**`Error: No valid credential sources found`**
Run `aws configure` and confirm with `aws sts get-caller-identity`.

**`Error: Backend initialization required`**
You changed `backend/dev.hcl`. Re-run `terraform init -backend-config=backend/dev.hcl`.

**`Error: Error acquiring the state lock`**
Another run is in progress, or a previous run died. Confirm nobody else is applying, then
`terraform force-unlock <LOCK_ID>` using the ID printed in the error.

**`Error: creating Security Group ... already exists`**
A previous run created it outside state. Import it or rename the security group.

---

## Verification checklist

Before you consider the lab complete:

- [ ] `bootstrap/` applied, `terraform output backend_config` prints real values
- [ ] `environments/dev` initialised with `-backend-config`
- [ ] `terraform fmt -check -recursive` exits 0 with no output
- [ ] every directory in the validate loop reports success
- [ ] `terraform apply` created a VPC with 2 public and 2 private subnets
- [ ] `terraform destroy` removed the billable resources

---

## Further exercises

1. Add a second environment (`environments/staging`) that reuses the same modules with a
   different CIDR and its own backend file.
2. Add an `outputs.tf` to `modules/security-group` that exports the rule count.
3. Move the flow log retention into a variable with a validation rule limiting it to the
   values CloudWatch actually accepts.
4. Write a `modules/ec2-instance` module and consume it from `environments/dev`.

---

## Requirements

- Terraform >= 1.5
- AWS provider ~> 5.0
- An AWS account with permission to create IAM roles, KMS keys, and VPC resources

## License

Released under the [MIT License](LICENSE).
