# Outpost on Azure AKS

This Terraform module provisions independent regional AKS infrastructure for
Outpost: managed identities, cluster and node pools, private work/findings
containers, a Key Vault, image registry and narrowly scoped identity grants.
Optional inventory adds separate inventory/outbox containers. It creates no
application enrollment, Helm releases, source connections or scans.

## Installation

The module follows the normal staged CDN publication and production promotion
process. The canonical address below becomes available after approved promotion;
a staged source merge alone does not establish public installation readiness.

Use Terraform 1.10 or later and ordinary Azure provider authentication. The
archive includes the exact locked AzureRM 5.12.0 provider selection. Customer
Terraform apply requires neither Python nor a private source checkout.

The archive is the existing standalone Azure Terraform root. Download the pinned
version into a new installation directory:

```sh
mkdir azure-outpost-release
cd azure-outpost-release
curl -fsSLO https://assets.relyance.ai/terraform/modules/relyance/aks/azurerm/releases/v0.1.0/module.zip
curl -fsSLO https://assets.relyance.ai/terraform/modules/relyance/aks/azurerm/releases/v0.1.0/README.md
curl -fsSLO https://assets.relyance.ai/terraform/modules/relyance/aks/azurerm/releases/v0.1.0/SHA256SUMS
shasum -a 256 -c SHA256SUMS
unzip -q module.zip -d installation
cd installation
terraform init -lockfile=readonly
```

Extract the verified archive before initialization so its provider lockfile is
preserved. The root keeps the existing Azure provisioner's resource addresses.

For protected remote state, use the included optional `bootstrap/` root, copy
`backend.tf.example` to `backend.tf`, fill the backend values from its actual
outputs, and reinitialize with that backend configuration before provisioning.
Copy the appropriate `examples/azure-*.tfvars.example` to your installation's
variable file and supply the actual trusted values. Run `terraform validate`,
review `terraform plan -out=installation.tfplan`, then apply only that reviewed
plan through the customer's normal process.

Relyance supplies the actual hosted-reader Google numeric subject. Do not derive
it from an email or substitute a CI identity. Supply bounded management and
storage network allowlists, or the supported private networking inputs. Additional
storage allowlists use exact installation/store keys; they do not widen Key Vault
access. Source Blob grants name exact existing containers, never an account,
subscription or resource group.

The module owns its Azure provider configuration using the supplied subscription
and tenant. Review the included `variables.tf`, examples and plan before apply.
The optional `bootstrap/` directory is a separate root for protected Blob state;
its outputs feed backend configuration rather than application secrets. Keep
state protected and preserve already installed resource ownership.

## Capacity and inventory

The standard profile uses two D4s_v5 system nodes and a separate autoscaled
D8s_v5 workload pool, min 0/max 3 by default. Confirm regional SKU availability,
quota and actual pod fit before installing the runtime. The separately bounded
`small_sandbox` profile uses two D4s_v5 system nodes and at most one E4s_v5 worker
node; inventory is rejected under that profile. Inventory requires the standard
profile and its normal production resource requests.

Inventory work and outbox containers remain separate from work and findings.
The independent hosted reader receives read access to inventory/findings, with
no source-credential or Key Vault write access. Customer source credentials stay
in the selected customer vault or workload environment.

## Runtime handoff

Send the applied nonsecret installation outputs to the Relyance operator through
the normal protected setup channel. Hosted queue/identity provisioning and
supported application enrollment remain separate operator steps. After those
steps, Relyance supplies a tenant-specific portable installation ZIP with the
validated accepted registration, exact image digests, hashed Helm/NAP assets,
locked installation providers and customer kubeconfig inputs. That ZIP uses the
existing handoff exporter; Python and the SDK remain generation-time tools.

This public provisioning archive contains no tenant registration or runtime
activation authority. Do not create placeholder authority files, point an
existing installation at a new state, or treat a successful infrastructure plan
as a completed inventory or data-inspection scan.

## Release provenance

Version 0.1.0 contains unmodified Terraform source from Relyance/cloud-infra commit
`66c4c478537a8f16ad2fc6426b87ac8c001dfd0a`, including provisioner PR241 and
portable handoff PR244. `SOURCE.json` records every archived source path and
SHA256. Verify the release's `SHA256SUMS` before use.

Validation includes 19 Azure provisioning mock plans, 16 hosted queue/IAM mock
plans and 18 native handoff tests. These are source/artifact checks. Deployed
images, active routing, actual inventory, findings transfer and scan completion
remain separate runtime qualification gates.
