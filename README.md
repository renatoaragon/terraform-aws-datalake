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
| `force_destroy` | bool | `false` | Allow destroying a non-empty bucket |
| `tags` | map(string) | `{}` | Extra tags merged onto all resources |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Data lake bucket name |
| `bucket_arn` | Data lake bucket ARN |
| `glue_database_name` | Glue catalog database name |
| `athena_workgroup` | Athena workgroup name |

## Design notes

- **Secure by default** — encryption, versioning and a full public-access block
  are always on; you cannot forget to enable them.
- **Reusable** — everything is parameterised through variables; the example just
  wires it up for one environment.
- **Validated inputs** — `environment` is constrained to known values so typos
  fail fast at plan time.
- **CI-checked** — GitHub Actions runs `terraform fmt -check` and
  `terraform validate` on the module and the example on every push.

## License

MIT — see [LICENSE](LICENSE).
