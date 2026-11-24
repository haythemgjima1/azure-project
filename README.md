# University Assignment Manager on Azure

Terraform deploys a three-tier university assignment CRUD website to three Ubuntu 22.04 VMs in separate Azure VNets. Nginx serves the frontend on `vm-web`, proxies `/api/` to the Flask/Gunicorn service on `vm-app`, and the service stores assignments in MySQL on `vm-db`.

## Architecture

- Region: `francecentral` by default; change `location` in `terraform.tfvars` if needed.
- Three VNets use `10.1.0.0/16`, `10.2.0.0/16`, and `10.3.0.0/16`.
- Only web↔app and app↔db are peered. No web↔db peering exists.
- Only `vm-web` has a VM public IP. The app and DB subnets use separate NAT gateways for outbound updates and Git clone access.
- The frontend supports creating, listing, editing, and deleting course assignments.
- The API is available at `/api/assignments`; `/api/instruments` is retained as a compatibility alias for the original project test path.

See [docs/architecture.md](docs/architecture.md) for addresses, traffic rules, and the peering diagram.

## Prerequisites

- An Azure subscription with permission to create resource groups, VNets, NAT gateways, public IPs, NSGs, and VMs in the chosen region.
- Azure CLI, Terraform 1.6+, Git, and a Bash environment (Linux, macOS, WSL, or Git Bash).
- A public SSH key and a public GitHub repository containing `backend/` and `frontend/`.
- `curl`, `jq`, `nc` (netcat), and OpenSSH client for `verify.sh`.

## Deploy

1. Follow [docs/commands.md](docs/commands.md) to log in, create an SSH key, publish the `app/` source, and configure `terraform/terraform.tfvars`.
2. From the project directory, run:

   ```bash
   bash scripts/deploy.sh
   ```

3. Wait for cloud-init on all three VMs to finish, then run:

   ```bash
   bash scripts/verify.sh
   ```

`deploy.sh` runs Terraform init, validate, plan, and apply. Review the plan and approve the apply when prompted. The first boot clones the public application repository, installs dependencies, initializes the database, and configures Nginx and systemd.

## Secrets and cost

Never commit `terraform.tfvars`, Terraform state, or SSH private keys. The DB password is marked sensitive, but it is also needed by cloud-init and is therefore present in Terraform state and VM provisioning metadata. Keep the local state private; use an appropriately protected remote backend before sharing state with others.

Azure VMs, NAT gateways, and their public IP addresses incur charges while provisioned (including NAT gateway hourly/data-processing costs). Review current regional pricing before deployment and run `bash scripts/destroy.sh` when finished. Do not leave the lab resources running.

## GUI extension

Part II is optional. [scripts/gui-setup.sh](scripts/gui-setup.sh) installs XFCE and xrdp on `vm-web`; it does not open port 3389 in the NSG. Use the SSH tunnel instructions in [docs/commands.md](docs/commands.md), and do not expose RDP publicly.

## Troubleshooting

- Check cloud-init output on a VM with `sudo cloud-init status --long` and `sudo tail -n 100 /var/log/cloud-init-output.log`.
- Check the app service with `sudo systemctl status university-api` and `sudo journalctl -u university-api -n 100 --no-pager`.
- Check MySQL with `sudo systemctl status mysql` on `vm-db`, and Nginx with `sudo nginx -t` on `vm-web`.
- The NAT gateways only provide outbound connectivity; they do not assign VM public IPs or permit inbound connections.
