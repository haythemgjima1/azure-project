# Operator commands

Run these commands from a Bash shell (Linux, macOS, WSL, or Git Bash). Replace angle-bracket placeholders and edit the example values before deployment. Never commit the private key, `terraform.tfvars`, or Terraform state.

## 1. Azure login and SSH key

```bash
az login
az account list --output table
az account set --subscription "<YOUR-SUBSCRIPTION-ID>"
az account show --output table
ssh-keygen -t ed25519 -C "university-assignment-lab" -f "$HOME/.ssh/id_ed25519"
```

Use the public IPv4 address of the machine that will SSH to Azure as `admin_ip_cidr`, with `/32` appended. Ensure your subscription has quota and regional capacity for three `Standard_A1_v2` VMs and two NAT gateways in `italynorth`.

## 2. Publish the project repository

Create an empty **public** GitHub repository, then publish the whole project from its root:

```bash
cd miniprojet-azure
git init
git add .
git commit -m "Add Azure university assignment project"
git branch -M main
git remote add origin "https://github.com/<YOUR-USER>/<YOUR-REPOSITORY>.git"
git push -u origin main
```

Because the project repository contains `app/backend/` and `app/frontend/`, use its URL as `repo_url` and keep `app_subdir = "app"` (the default). Cloud-init clones the repository and copies those folders to the app and web VMs.

## 3. Configure and deploy

```bash
cd miniprojet-azure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set your subscription ID, lowercase student identifier, actual administrator `/32`, SSH **public** key path, strong DB password, and public repository URL. The password must have at least 12 characters from letters, digits, `_ . : @ % + -`, and must not contain quotes or `$`.

```bash
cd ..
bash scripts/deploy.sh
```

The script checks Azure CLI login, then runs `terraform init`, `terraform validate`, `terraform plan`, and `terraform apply`. Inspect and approve the Terraform apply prompt. Do not run deployment against a subscription or student resource group you do not own.

## 4. Verify the deployment

```bash
bash scripts/verify.sh
terraform -chdir=terraform output
```

The verifier checks the six seeded records and CRUD operations, VM public-IP count, web→app and app→DB connectivity, blocked web→DB and external app-port access, and web's effective routes. It requires `az`, Terraform, `curl`, `jq`, `nc`, and SSH. Run it from the same machine and with the same Terraform working directory/state as deployment.

## 5. Optional XFCE/xrdp GUI on vm-web

Install the GUI remotely, without adding an inbound 3389 rule:

```bash
KEY="$(terraform -chdir=terraform output -raw ssh_private_key_path)"
FQDN="$(terraform -chdir=terraform output -raw web_fqdn)"
scp -i "$KEY" scripts/gui-setup.sh "azureuser@$FQDN:/tmp/gui-setup.sh"
ssh -i "$KEY" "azureuser@$FQDN" 'sudo bash /tmp/gui-setup.sh'
ssh -i "$KEY" "azureuser@$FQDN" 'sudo passwd azureuser'
ssh -i "$KEY" -L 13389:127.0.0.1:3389 "azureuser@$FQDN"
```

Keep the final SSH session open, then connect an RDP client to `127.0.0.1:13389` using `azureuser` and the Linux password set above. SSH password authentication remains disabled; the password is for the tunneled desktop session only. Port 3389 is not exposed to the Internet.

## 6. Destroy resources

After saving any required screenshots and project evidence:

```bash
bash scripts/destroy.sh
```

This runs `terraform destroy`, then checks Azure's resource-group list for the project's group. NAT gateways, public IPs, and VMs incur charges until removed.
