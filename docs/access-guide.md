# Live Access, Network Exploration & Verification Guide

All three tiers, networking, monitoring, HTTPS (Let's Encrypt), and the Part II XFCE desktop GUI are deployed and running in **`germanywestcentral`** under resource group **`rg-miniprojet-haythem`**.

---

## 1. Deployment Summary

| Resource / Tier | Name | Network / Address | Public Access | Service / Role |
|---|---|---|---|---|
| **Resource Group** | `rg-miniprojet-haythem` | `germanywestcentral` | — | Contains all project resources |
| **Tier 1 (Web)** | `vm-web` (`Standard_D2s_v6`) | `vnet-web` (`10.1.0.0/16`) / `subnet-web` (`10.1.1.0/24`) / **`10.1.1.4`** | **`4.184.144.13`**<br>`miniprojet-haythem.germanywestcentral.cloudapp.azure.com` | Nginx (HTTP `80` + Let's Encrypt HTTPS `443`), static frontend, `/api/` reverse proxy, XFCE + `xrdp` (`3389` private) |
| **Tier 2 (App)** | `vm-app` (`Standard_D2s_v6`) | `vnet-app` (`10.2.0.0/16`) / `subnet-app` (`10.2.1.0/24`) / **`10.2.1.4`** | **None** (outbound via `nat-app` / `pip-nat-app`) | Flask + Gunicorn (`university-api`) on port `5000` |
| **Tier 3 (DB)** | `vm-db` (`Standard_D2s_v6`) | `vnet-db` (`10.3.0.0/16`) / `subnet-db` (`10.3.1.0/24`) / **`10.3.1.4`** | **None** (outbound via `nat-db` / `pip-nat-db`) | MySQL 8.0 (`3306`), DB `university_assignments`, user `appuser@10.2.1.%` |
| **Azure DB MySQL (PaaS)** | `mysql-miniprojet-haythem-01` (`B_Standard_B1ms`) | `subnet-db` (`10.3.1.0/24`) via Private Endpoint / **`10.3.1.5`** (Private DNS: `mysql-miniprojet-haythem-01.mysql.database.azure.com`) | **None** (Private Endpoint only, `public_network_access = Disabled`) | MySQL 8.0 Flexible Server, DB `university_assignments` — **automatic failover** backup if `vm-db` is unreachable |
| **NSGs** | `nsg-web`, `nsg-app`, `nsg-db` | Associated per subnet | — | Least-privilege inbound rules + priority `4096` Deny All |
| **Peerings** | `peer-web-to-app`, `peer-app-to-web`, `peer-app-to-db`, `peer-db-to-app` | `vnet-web ↔ vnet-app ↔ vnet-db` | — | Non-transitive (no `web ↔ db` route) |
| **Monitoring** | `alert-vm-web-high-cpu`, `ag-miniprojet-haythem` | Scope: `vm-web` | — | Azure Monitor CPU > 80% alert |

---

## 2. Visiting the Website & Testing the API

* **HTTPS (Let's Encrypt certificate):**
  `https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com`
* **HTTP:**
  `http://miniprojet-haythem.germanywestcentral.cloudapp.azure.com` (or `http://4.184.144.13`)
* **API Health & Data:**
  * `https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com/api/health`
  * `https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com/api/assignments` (also aliased at `/api/instruments`)

Quick PowerShell test:
```powershell
Invoke-RestMethod "https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com/api/health"
Invoke-RestMethod "https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com/api/assignments" | Format-Table id, course_code, title, status
```

---

## 3. Accessing Each VM via SSH (Jump Host Chain)

SSH key authentication is required (`C:\Users\user\.ssh\id_ed25519`), and `nsg-web` allows TCP `22` only from `admin_ip_cidr` (`102.107.134.98/32`).

> **If your public IP changes later:** check your new IP with `(Invoke-RestMethod https://api.ipify.org)`, update `admin_ip_cidr` in [terraform.tfvars](file:///c:/Azure-project/miniprojet-azure/terraform/terraform.tfvars#L4), and run `terraform -chdir=c:\Azure-project\miniprojet-azure\terraform apply`.

### Tier 1 — `vm-web` (`10.1.1.4`)
```powershell
ssh -i "C:\Users\user\.ssh\id_ed25519" azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com
```
Useful commands on `vm-web`:
```bash
hostname -I
sudo systemctl status nginx
sudo nginx -t
cat /etc/nginx/conf.d/app.conf
```

### Tier 2 — `vm-app` (`10.2.1.4`, 1-hop jump through `vm-web`)
```powershell
ssh -i "C:\Users\user\.ssh\id_ed25519" -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com azureuser@10.2.1.4
```
Useful commands on `vm-app`:
```bash
hostname -I
sudo systemctl status university-api
curl -s http://127.0.0.1:5000/api/health
```

### Tier 3 — `vm-db` (`10.3.1.4`, 2-hop jump through `vm-web` then `vm-app`)
```powershell
ssh -i "C:\Users\user\.ssh\id_ed25519" -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com,azureuser@10.2.1.4 azureuser@10.3.1.4
```
Useful commands on `vm-db`:
```bash
hostname -I
sudo systemctl status mysql
sudo mysql -e "SELECT id, course_code, title, status FROM university_assignments.assignments;"
sudo mysql -e "SHOW GRANTS FOR 'appuser'@'10.2.1.%';"
```

---

## 4. Accessing the Ubuntu Desktop GUI (Part II — XFCE + Browser)

Port `3389` is **not** exposed to the Internet in `nsg-web`. Connect securely through an SSH tunnel:

1. **Open an SSH tunnel** in a PowerShell window (leave this window open while using Remote Desktop):
   ```powershell
   ssh -i "C:\Users\user\.ssh\id_ed25519" -N -L 13389:127.0.0.1:3389 azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com
   ```
2. **Open Windows Remote Desktop (`mstsc.exe`)**:
   * Press `Win + R`, type `mstsc`, press Enter.
   * **Computer:** `127.0.0.1:13389`
   * **Username:** `azureuser`
   * **Password:** `AzureDemo2026!`
3. **Open the web app inside the XFCE desktop**:
   * Double-click **University Assignment Manager** on the XFCE desktop, **or**
   * Open **Applications → Internet → Web** (`epiphany`) and visit:
     * `http://localhost` or `https://miniprojet-haythem.germanywestcentral.cloudapp.azure.com`

---

## 5. Inspecting Networks, Peerings, NSGs & Proving Isolation

### A. In Azure Portal (for your report screenshots)
1. Go to **Resource groups → `rg-miniprojet-haythem`** to view all 34 resources together.
2. **VNets & Peerings**: Open **`vnet-web`**, **`vnet-app`**, and **`vnet-db`** → **Address space** / **Subnets** / **Peerings** (`Connected` status).
3. **Effective Routes (proof of non-transitivity)**: Open **`nic-vm-web` → Effective routes** (under *Help*). You will see `10.1.0.0/16` (VNet local) and `10.2.0.0/16` (VNet peering), and **no route** to `10.3.0.0/16`.
4. **NSGs**: Open **`nsg-web`**, **`nsg-app`**, and **`nsg-db` → Inbound security rules** and **Subnets**.
5. **Public IPs & NAT Gateways**:
   * Open **`vm-web`**, **`vm-app`**, and **`vm-db` → Networking** to show only `vm-web` has a VM Public IP (`4.184.144.13`).
   * Open **`nat-app`** and **`nat-db`** to show outbound-only NAT for `subnet-app` and `subnet-db`.
6. **Monitoring**: Open **`rg-miniprojet-haythem` → Alerts → Alert rules** (`alert-vm-web-high-cpu`) or **`vm-web` → Metrics**.

### B. Via Azure CLI (PowerShell)
```powershell
# List all resources in the resource group
az resource list -g rg-miniprojet-haythem -o table

# Show VMs, sizes, private IPs, and public IPs
az vm list -g rg-miniprojet-haythem -d --query "[].{name:name, size:hardwareProfile.vmSize, privateIps:privateIps, publicIps:publicIps, state:powerState}" -o table

# Show all 3 VNets and their subnets
az network vnet list -g rg-miniprojet-haythem --query "[].{vnet:name, address:addressSpace.addressPrefixes[0], subnets:subnets[].{name:name, prefix:addressPrefix}}" -o json

# Show VNet peerings and peering state
az network vnet peering list -g rg-miniprojet-haythem --vnet-name vnet-web -o table
az network vnet peering list -g rg-miniprojet-haythem --vnet-name vnet-app -o table
az network vnet peering list -g rg-miniprojet-haythem --vnet-name vnet-db -o table

# Show effective route table of vm-web (proves 10.2.0.0/16 is present and 10.3.0.0/16 is absent)
az network nic show-effective-route-table -g rg-miniprojet-haythem -n nic-vm-web -o table

# Show NSG rules
az network nsg rule list -g rg-miniprojet-haythem --nsg-name nsg-web -o table
az network nsg rule list -g rg-miniprojet-haythem --nsg-name nsg-app -o table
az network nsg rule list -g rg-miniprojet-haythem --nsg-name nsg-db -o table

# Show NAT gateways
az network nat gateway list -g rg-miniprojet-haythem -o table
```

### C. Live Connectivity & Non-Transitivity Tests (from `vm-web` & `vm-app`)
```powershell
# 1. vm-web CAN reach vm-app :5000 (allowed by vnet-web<->vnet-app peering + nsg-app)
ssh -i "C:\Users\user\.ssh\id_ed25519" azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com "curl -sS http://10.2.1.4:5000/api/health"

# 2. vm-web CANNOT reach vm-db :3306 (peering is non-transitive + nsg-db blocks 10.1.1.0/24)
ssh -i "C:\Users\user\.ssh\id_ed25519" azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com "nc -zv -w 3 10.3.1.4 3306"

# 3. vm-app CAN reach vm-db :3306 (allowed by vnet-app<->vnet-db peering + nsg-db)
ssh -i "C:\Users\user\.ssh\id_ed25519" -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com azureuser@10.2.1.4 "nc -zv -w 3 10.3.1.4 3306"
```

---

## 6. Connectivity Tests Summary

| Test | From | To | Expected Result | Verified |
|---|---|---|---|---|
| External → `vm-web` `:80`/`:443` | Internet | `4.184.144.13` | ✅ HTTP 200 / HTTPS cert valid | ✓ |
| External → `vm-web` `:5000` | Internet | `4.184.144.13:5000` | ❌ Blocked by `nsg-web` | ✓ |
| `vm-web` → `vm-app` `:5000` | `10.1.1.4` | `10.2.1.4:5000` | ✅ Allowed (peering + `nsg-app`) | ✓ |
| `vm-web` → `vm-db` `:3306` | `10.1.1.4` | `10.3.1.4:3306` | ❌ Blocked (non-transitive + `nsg-db`) | ✓ |
| `vm-app` → `vm-db` `:3306` | `10.2.1.4` | `10.3.1.4:3306` | ✅ Allowed (peering + `nsg-db`) | ✓ |
| `vm-app` → PaaS MySQL `:3306` | `10.2.1.4` | `10.3.1.5:3306` | ✅ Allowed (Private Endpoint DNS) | ✓ |

---

## 7. Azure Database for MySQL (Managed PaaS — Automatic Failover)

### What it is
`mysql-miniprojet-haythem-01` is an **Azure Database for MySQL Flexible Server** (B_Standard_B1ms, v8.0.21) deployed with a **Private Endpoint** (`pe-mysql-db`) inside `subnet-db`. Its private IP is **`10.3.1.5`**, co-located alongside `vm-db` (`10.3.1.4`).

It has **no public Internet access** (`public_network_access = Disabled`). It is reachable only from within `vnet-db` and `vnet-app` (via Private DNS Zone `privatelink.mysql.database.azure.com` linked to both VNets).

### How the automatic failover works (`app.py`)
The Flask backend (`vm-app`) uses a `_connect()` helper that:
1. **Tries `DB_HOST` = `10.3.1.4`** (the `vm-db` VM) first, with a 4-second timeout.
2. **On failure** (connection refused, timeout, host unreachable), falls back to **`DB_HOST_FALLBACK` = `10.3.1.5`** (the PaaS Flexible Server).
3. All CRUD routes use `_connect()` transparently — no code change needed to switch targets.

Environment variables on `vm-app` (`/etc/instruments.env`):
```ini
DB_HOST=10.3.1.4
DB_HOST_FALLBACK=10.3.1.5
DB_USER=appuser
DB_PASS=AppPass2026!
DB_NAME=university_assignments
```

### Verified failover results
| Test | vm-db state | Active DB host | COUNT(*) |
|---|---|---|---|
| TEST 1 (normal) | Running | `10.3.1.4` (vm-db) | 6 ✓ |
| TEST 2 (vm-db blocked via `iptables REJECT`) | Unreachable | `10.3.1.5` (PaaS) | 6 ✓ |
| TEST 3 (vm-db restored) | Running | `10.3.1.4` (vm-db) | 6 ✓ |

### Inspect via CLI (jump through vm-app)
```powershell
# Connect directly to PaaS MySQL from vm-app (via Private Endpoint DNS)
ssh -i "C:\Users\user\.ssh\id_ed25519" `
  -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com `
  azureuser@10.2.1.4 `
  "mysql -h mysql-miniprojet-haythem-01.mysql.database.azure.com -u mysqladmin -pMysqlAdmin2026! university_assignments -e 'SELECT * FROM assignments;'"

# Or use the Private IP directly
ssh -i "C:\Users\user\.ssh\id_ed25519" `
  -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com `
  azureuser@10.2.1.4 `
  "mysql -h 10.3.1.5 -u mysqladmin -pMysqlAdmin2026! university_assignments -e 'SELECT * FROM assignments;'"

# Check the failover env vars on vm-app
ssh -i "C:\Users\user\.ssh\id_ed25519" `
  -J azureuser@miniprojet-haythem.germanywestcentral.cloudapp.azure.com `
  azureuser@10.2.1.4 `
  "sudo cat /etc/instruments.env"
```

### View in Azure Portal
1. **Azure Database for MySQL Flexible Servers** → `mysql-miniprojet-haythem-01`
   - **Overview**: server name, region, tier, MySQL version, status
   - **Networking**: confirm `Public network access = Disabled` and Private Endpoint shown
2. **Private endpoints** (search in top bar) → `pe-mysql-db`
   - **DNS configuration** tab: shows `10.3.1.5` and FQDN `mysql-miniprojet-haythem-01.mysql.database.azure.com`
3. **Private DNS zones** → `privatelink.mysql.database.azure.com`
   - **Virtual network links**: `vnet-app-link` and `vnet-db-link` both shown as `Linked`
   - **Record sets**: A-record for `mysql-miniprojet-haythem-01` → `10.3.1.5`

---

## 8. When You Finish (Stop Charges)

Because all 3 `Standard_D2s_v6` VMs, 2 NAT Gateways, and 3 Public IPs are currently running, destroy the resource group once you finish taking screenshots, recording the video, and presenting:

```powershell
terraform -chdir="c:\Azure-project\miniprojet-azure\terraform" destroy
```
