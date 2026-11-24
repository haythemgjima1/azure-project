# Demo script (12 minutes)

Use a live deployment only if it is available in your own subscription. Otherwise, present the Terraform and application code without describing unrun tests as successful.

| Time | Demo |
|---|---|
| 0:00–1:00 | Introduce the ISET Mahdia mini-project, objectives, and assignment-manager CRUD use case. |
| 1:00–2:30 | Show the architecture diagram, IP plan, and three separate tiers. |
| 2:30–4:00 | Walk through Terraform variables, tier/peering locals, NSGs, NAT gateways, and VM resources. |
| 4:00–5:00 | Explain cloud-init and the public Git repository layout used to provision web and app code. |
| 5:00–6:30 | Open the site; list assignments and create a temporary assignment. |
| 6:30–7:30 | Edit the assignment, change its status, then delete it. |
| 7:30–9:00 | Show the Flask routes and parameterized SQL, then the MySQL schema and restricted appuser grant. |
| 9:00–10:30 | Demonstrate verification: web reaches app, app reaches DB, web cannot reach DB, and app port is not public. |
| 10:30–11:15 | Explain peering non-transitivity and the two-hop SSH path to DB. |
| 11:15–12:00 | Show cost considerations, optional GUI-over-SSH tunnel, and the destroy/cleanup procedure. |

Reserve a few minutes for questions if the presentation slot is 15 minutes. Keep passwords, private keys, and tokens out of screen recordings and terminal history.
