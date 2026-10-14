# Dashboard register

An index of dashboards that live in their own repositories rather than in this tree.

Some dashboards ship as part of a larger application, where the dashboard and the exporter that
feeds it are versioned together and would drift if copied here. This register points to those,
so they can be found alongside the dashboards held directly in this repository.

Contribution requirements are in the [root README](../README.md). Entries here are expected to
meet the same bar: no credentials, no customer identifiers, no internal endpoints, and the
required metrics documented.

## Register

| Dashboard | Source repository | Format | Required data | Maintainer |
| --- | --- | --- | --- | --- |
| Platform Billing Overview | [rdwj/platform-billing-operator](https://github.com/rdwj/platform-billing-operator) ([dashboard JSON](https://github.com/rdwj/platform-billing-operator/blob/main/config/grafana/billing-overview.json)) | Grafana, schemaVersion 39 | Prometheus; `billing_*` metrics and four recording rules exported by the operator | [@rdwj](https://github.com/rdwj) |

## Adding an entry

Add a row to the table above, in alphabetical order by dashboard name, and open a pull request.

| Column | What to put in it |
| --- | --- |
| Dashboard | The dashboard title as it appears in the tool, so people can match what they see to this list. |
| Source repository | Link to the repository, plus a direct link to the dashboard definition if it is not obvious from the root. |
| Format | Perses or Grafana, with the schema or spec version you tested against. |
| Required data | Datasource type, the metric families consumed, and anything extra the dashboard depends on such as recording rules, exporters, or operators. |
| Maintainer | GitHub handle or team to contact. Not necessarily the author. |

If an entry needs more than a table row to explain, add `dashboards/<repository-name>.md` and link
to it from the Dashboard column. Keep the table itself scannable.

Entries point at repositories outside this one, so they can move or go stale. If you find a dead
link, open a pull request removing the row and say so in the description.

## Platform Billing Overview

Provider-side view of a Models-as-a-Service billing deployment, covering revenue, rating
throughput, tenant state, and budget consumption in one place. Intended for the platform team
operating the service rather than for tenants.

Ten panels: monthly recurring revenue, events rated, payment failure rate, tenant state
distribution, revenue per tenant over 24 hours, usage volume by ingest result, drift status,
budget utilization, churn risk, and tenant balance. Templated on `tenant_id`, defaulting to a
24 hour window with a 30 second refresh.

Instrumented metrics come from the operator's controller-manager metrics endpoint:
`billing_tenant_balance`, `billing_tenant_state`, `billing_budget_utilization`,
`billing_events_rated_total`, `billing_ingest_total`, `billing_drift_pct`, and
`billing_drift_exceeded`.

Four panels read recording rules rather than raw series: `billing:mrr:sum`,
`billing:payment_failure:rate`, `billing:revenue_per_tenant:sum`, and `billing:churn_risk:ratio`.
These ship with the operator as a `PrometheusRule` in `config/prometheus/rules.yaml`. The
dashboard renders empty panels without them, so apply that resource before importing.

The operator is pre-1.0 and its metric names are not yet stable. Pin to a tagged release when
one is available rather than tracking `main`.
