# Security

Default deny for private workloads, scoped roles, no public management ports, no secrets or Terraform state in source control. Never apply tenant-level changes automatically. Federated OIDC should be scoped to trusted branch/environment after approval. Include security regression tests.
