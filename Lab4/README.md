# Lab 4: Remote State and Workspaces

## What is in this folder

| File | What it does |
|------|--------------|
| `main.tf` | The Lab 3 code, with the single EC2 instance replaced by an AutoScaling Group (ASG). |
| `fr.tfvars` | Values for France: min 1, max 2 instances. |
| `de.tfvars` | Values for Germany: min 2, max 3 instances. |

## The ideas

- **State**: the file where Terraform remembers what it created. By default it is `terraform.tfstate` on your laptop.
- **Remote state**: the same file, stored in an S3 bucket instead. The DynamoDB table is a lock so two people cannot apply at the same time.
- **Launch template**: the "recipe" for an instance (AMI, type, ssh key, security group).
- **AutoScaling Group**: keeps between `asg_min` and `asg_max` instances running, using the recipe.
- **`.tfvars` file**: a file of variable values, passed with `-var-file=...`.
- **Workspace**: a separate state for the same code. One code, several deployments (`france`, `germany`).

The bucket `terraform-state-w9e85` already exists (the teacher's). We only use it, we do not create it.

## Commands, in order

### 1. Deploy with local state

```bash
terraform init
terraform apply -var-file=fr.tfvars
```

This creates the ASG with 1 instance. The state is still local, so there is something to migrate.

### 2. Migrate the state to S3

In `main.tf`, uncomment the `backend "s3"` block and replace `XX` with your student number. Then:

```bash
terraform init -migrate-state
```

Answer `yes`. The state now lives in the bucket.

### 3. Create the `france` workspace and move the state into it

```bash
terraform state pull > default.tfstate
terraform workspace new -state=default.tfstate france
terraform workspace select default
terraform state rm $(terraform state list)
terraform workspace select france
terraform plan -var-file=fr.tfvars
```

- `state pull` downloads a copy of the current state.
- `workspace new -state=...` creates `france` and puts that copy in it.
- `state rm` makes the `default` workspace forget the resources. Nothing is deleted in AWS. Without it, two workspaces would both think they own the same instances.
- The final `plan` should say `No changes`.

### 4. Create `germany` and deploy a second ASG

```bash
terraform workspace new germany
terraform apply -var-file=de.tfvars
```

This workspace starts with an empty state, so Terraform creates a whole new set of resources, with min 2 and max 3.

### 5. Clean up

```bash
terraform workspace select france
terraform destroy -var-file=fr.tfvars
terraform workspace select germany
terraform destroy -var-file=de.tfvars
```

## Useful commands

```bash
terraform workspace show   # which workspace am I in?
terraform workspace list   # all workspaces
terraform state list       # what this workspace manages
```

## Things to know

- Nothing forces `fr.tfvars` to go with `france`. Check with `terraform workspace show` before each apply.
- `dynamodb_table` prints a deprecation warning on recent Terraform versions. It still works.
- The repo `.gitignore` ignores `*.tfvars`. To commit them: `git add -f Lab4/*.tfvars`.
- An ASG has no single public IP, so the output is `asg_name`. Find the instances in the EC2 console under the name `lab4-france` or `lab4-germany`.
