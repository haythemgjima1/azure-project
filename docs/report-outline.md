# Report outline (target: 18 pages)

Use this as a structure for a 15–25 page PDF. Replace prompts with your own measured results and screenshots; do not claim a deployment or test succeeded unless you performed it.

1. **Cover** — project title, ISET Mahdia, course, student names, date.
2. **Abstract** — problem, solution, and a short results summary.
3. **Project objectives** — three-tier deployment and learning outcomes.
4. **Requirements** — functional, network, security, and deployment requirements.
5. **Architecture overview** — explain web, app, and DB responsibilities.
6. **Architecture diagram** — include the Mermaid diagram from `architecture.md`, rendered.
7. **Addressing plan** — VNet, subnet, and static private-IP table.
8. **Azure services** — VM, VNet peering, NSG, NAT gateway, public IP, and DNS label.
9. **Network security** — inbound NSG policy and admin SSH path.
10. **Peering and routing** — explain why web cannot transit through app to reach DB.
11. **Terraform organization** — providers, variables, locals/for_each, resources, and outputs.
12. **Provisioning workflow** — cloud-init bootstrapping and GitHub source layout.
13. **Database design** — assignment columns, seed data, and least-privilege app account.
14. **Backend/API** — Flask/Gunicorn services, CRUD routes, validation, parameterized SQL.
15. **Frontend** — assignment list, add/edit form, status, and delete workflow.
16. **Deployment evidence** — Terraform plan/apply and Azure resource views.
17. **Verification results** — copy actual `verify.sh` output and discuss each check.
18. **GUI extension** — optional XFCE/xrdp over SSH tunnel; note whether completed.
19. **Costs and cleanup** — actual cost estimate/source, NAT/VM lifetime, destroy evidence.
20. **Conclusion and improvements** — lessons, limitations, and next steps.
21. **Appendix** — selected Terraform, cloud-init, API, and command references.

## Screenshot checklist

- Azure portal account/subscription context visible in each Azure portal screenshot, with personal identifiers minimized where appropriate.
- Resource group and all three VMs.
- Three VNets/subnets, peering links, and subnet NSG associations.
- NAT gateway and NAT public IP associations for app and DB subnets.
- VM public-IP view showing only `vm-web` has a VM public address.
- Web page with assignment records and at least one CRUD operation.
- Successful verification output, including route/connectivity checks.
- Optional desktop session over the SSH tunnel.
- Resource group absent after cleanup.

Capture only screenshots from your own account and actual deployment. Do not include SSH private keys, passwords, access tokens, or unredacted secrets.
