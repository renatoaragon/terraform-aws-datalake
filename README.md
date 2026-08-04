# terraform-aws-datalake

![CI](https://github.com/renatoaragon/terraform-aws-datalake/actions/workflows/ci.yml/badge.svg)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.3-7B42BC)
![AWS Provider](https://img.shields.io/badge/aws-~%3E5.0-FF9900)
![License](https://img.shields.io/badge/license-MIT-green)

A reusable **Terraform module** that provisions the storage and query layer of an
AWS data lake: an **S3 bucket**, a **Glue Catalog database**, and an **Athena
workgroup**, wired together with sensible, secure defaults.

> Built to demonstrate how I write infrastructure as code: a clean reusable
> module, a runnable example, input validation, and CI that enforces formatting
> and validates the configuration on every change.

## What it creates

| Resource | Purpose | Defaults |
|---|---|---|
| S3 bucket | Data lake storage (`raw/`, `curated/`, `athena-results/`) | Versioned, SSE-S3 encrypted, public access blocked |
| Lifecycle rule | Cost control on raw data | `raw/` transitions to `STANDARD_IA` after 30 days |
| Glue database | Table catalog for query engines | Named `<prefix>_<env>` |
| Athena workgroup | Isolated query execution | Enforced config, results encrypted, CloudWatch metrics |

## Usage

```hcl
module "data_lake" {
  source = "github.com/renatoaragon/terraform-aws-datalake//modules/data_lake"

  name_prefix = "acme"
  environment = "dev"

  tags = {
    Team    = "data-platform"
    Project = "analytics"
  }
}
```

A complete, runnable configuration lives in [`examples/basic`](examples/basic).

```bash
cd examples/basic
terraform init
terraform plan
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | — | Prefix for bucket and catalog names |
| `environment` | string | — | One of `dev`, `staging`, `prod` (validated) |
| `raw_transition_days` | number | `30` | Days before `raw/` objects move to `STANDARD_IA` |
| `athena_results_expiration_days` | number | `30` | Days before Athena query results are deleted (they are a cache, not data) |
| `noncurrent_version_expiration_days` | number | `90` | Days a noncurrent object version is kept before deletion (versioning is on) |
| `access_log_bucket` | string | `""` | Existing bucket for S3 server access logs; empty disables logging |
| `access_log_prefix` | string | `"s3-access-logs/"` | Key prefix for the access logs |
| `force_destroy` | bool | `false` | Allow destroying a non-empty bucket |
| `tags` | map(string) | `{}` | Extra tags merged onto all resources |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Data lake bucket name |
| `bucket_arn` | Data lake bucket ARN |
| `glue_database_name` | Glue catalog database name |
| `athena_workgroup` | Athena workgroup name |

## Design principles

Tools are the most disposable part of data engineering, and infrastructure is no
exception. Terraform could be OpenTofu or Pulumi, and AWS could be another cloud,
without changing what this module is for. What lasts is the posture: infrastructure
that is secure by default, fails at plan time rather than apply time, and is reused
rather than copied. So this module is built around those guarantees, not around one
provider's syntax.

This is the foundation the rest of the platform sits on: the S3, Glue and Athena
layer that stores and exposes the data a lakehouse like
[delta-lakehouse-mlflow](https://github.com/renatoaragon/delta-lakehouse-mlflow)
writes and an analytics layer like
[dbt-duckdb-analytics](https://github.com/renatoaragon/dbt-duckdb-analytics)
queries. The principles it holds to:

- **Secure by default, not by remembering.** Encryption, versioning, a full
  public-access block and a TLS-only bucket policy are always on. Safety you have to
  opt into is safety someone eventually forgets.
- **Fail at plan, not at apply.** Every constraint the AWS API would reject at apply
  time is validated at plan time instead, so a bad input is caught in seconds, not
  halfway through provisioning.
- **Reusable, not copied.** The module is parameterised and the example just wires it
  for one environment. Infrastructure that is copy-pasted drifts; a module stays one
  source of truth.

## Design notes

- **Secure by default** — encryption, versioning and a full public-access block
  are always on; you cannot forget to enable them. A bucket policy also denies
  every request that did not arrive over TLS: encryption at rest says nothing
  about the wire, and S3 accepts plain HTTP unless a policy refuses it.
  Server access logging is available (`access_log_bucket`) but off by default,
  since it needs a destination bucket and would otherwise mean unrequested cost.
- **Reusable** — everything is parameterised through variables; the example just
  wires it up for one environment.
- **Validated inputs** — every constraint the AWS API would reject at apply time
  is enforced at **plan time** instead: `environment` is constrained to known
  values, `name_prefix` must satisfy S3 bucket-name rules (it becomes part of
  the bucket name), and `raw_transition_days` respects the 30-day STANDARD_IA
  minimum.
- **Query-friendly identifiers** — the Glue database name normalizes hyphens to
  underscores, so a prefix like `acme-corp` never produces a database that needs
  quoting in every Athena query.
- **CI-checked** — GitHub Actions runs `terraform fmt -check`,
  `terraform validate` and **tflint** (recommended preset) on the module and the
  example on every push.

## License

MIT — see [LICENSE](LICENSE).
