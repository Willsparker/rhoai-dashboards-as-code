# OpenShift AI Community Dashboards

A community-driven collection of custom dashboards as code for Red Hat OpenShift AI (RHOAI). This repository brings together contributions from field teams, customers, and the wider community to answer operational questions specific to their AI workloads and organizations.

Keep dashboard definitions in Git, adapt them to your environment, and deploy them through your chosen dashboard tooling or GitOps workflow.

## What is a custom dashboard?

A custom dashboard extends or reorganizes the views provided out of the box by OpenShift AI. It can expose additional runtime metrics, apply organization-specific filters and calculations, or bring signals from several domains into one view. It queries the underlying observability data rather than querying other dashboards.

Examples of contributions we welcome:

| Example | What it helps you understand |
| --- | --- |
| **Extended vLLM diagnostics** | Add metrics beyond the built-in Perses dashboard, such as request queuing, KV cache utilization, prefix cache behavior, and latency distributions, where exposed by the deployed vLLM version. Use these to investigate throughput or latency changes. |
| **Usage attribution and showback** | Use available RHOAI Models-as-a-Service usage data, such as token consumption and request counts, with subscription-to-team mappings and organization-defined rates to estimate costs by team or cost center. Document attribution, pricing, and calculation assumptions; usage metrics alone are not a billing system. |
| **Organization-wide AI operations overview** | Combine vLLM performance, llm-d serving health, infrastructure and GPU health, and usage into a single view organized around the models, projects, or services an organization operates. |
| **GPU capacity and efficiency** | Combine GPU utilization and memory metrics with serving demand and workload placement to identify idle capacity, resource pressure, and opportunities to adjust model deployment sizes. Requires the relevant GPU and cluster exporters. |
| **Inference service objectives** | Track latency targets, request success rates, and throughput by model or service. Where available, link to traces and logs to investigate periods when service targets are missed. |

These are example use cases, not a list of dashboards already included in this repository. Available metrics, labels, and integrations depend on the deployed versions and configuration.

## Observability data sources

Dashboards should use telemetry from OpenShift AI workloads and the OpenShift platform supporting them:

- **Prometheus for metrics:** the primary source for model serving, platform health, and available usage metrics. OpenShift platform metrics may also be accessed through Thanos, depending on the environment.
- **Tempo for distributed traces:** use when tracing and workload instrumentation are enabled.
- **Loki for logs, when separately configured:** an optional source for environments with a logging stack. Do not assume Loki is installed by OpenShift AI.

The documented [OpenShift AI observability stack](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/managing_openshift_ai/managing-observability_managing-rhoai) uses Prometheus and Tempo, with OpenTelemetry for collection. [MaaS observability](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html-single/govern_llm_access_with_models-as-a-service/index) describes usage tracking and showback inputs. Consult the documentation for your installed release.

Each contribution must identify its actual data sources, required metrics or trace attributes, collection prerequisites, and access requirements. Dashboard filters do not replace backend authorization or tenant isolation.

## Dashboard formats

- **Perses:** dashboard definitions in JSON or YAML, including `PersesDashboard` Kubernetes resources where appropriate. Specify whether a file is a native Perses resource or an operator custom resource and explain how to deploy it. See the [Perses CLI documentation](https://perses.dev/perses/docs/cli/).
- **Grafana:** dashboard JSON, optionally accompanied by YAML provisioning configuration or an operator resource with deployment instructions. See [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards).

Contributions can target either tool. Equivalent versions for both are welcome but are not required. Document the tested dashboard tool version and any required plugins; the formats are not interchangeable.

## Contributing

Submit a pull request containing the dashboard files and a short README with:

- Purpose, intended audience, and an optional screenshot using sanitized data.
- Maintainer or owner.
- Tested OpenShift AI, runtime, and dashboard tool versions.
- Required data sources, metric names, labels, units, and any recording rules or additional exporters.
- Import or deployment instructions, variables to configure, and known limitations.
- Any attribution mappings or cost assumptions used for showback.

Remove credentials, customer identifiers, internal endpoints, and sensitive data before contributing. Parameterize environment-specific values where possible.

## Support

Dashboards in this repository are community contributions, not Red Hat supported product content. Validate compatibility, queries, and data access controls before deployment. The repository provides reusable dashboard definitions and guidance; it does not install an observability backend or provide a dashboard-authoring service.

