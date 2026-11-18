# docker-azure-pipelines-agent

Self-hosted [Azure Pipelines](https://learn.microsoft.com/azure/devops/pipelines/agents/agents) agent for Kubernetes and Docker, with the agent built into the image.

Images are built for `linux/amd64` and `linux/arm64`, run as a non-root user and ship with an SBOM, build provenance and a keyless signature. To run them on Kubernetes with KEDA autoscaling, use the [azure-pipelines-agent Helm chart](https://github.com/Think-Cube/azure-pipelines-agent-chart).

## Images

Images are published to GitHub Container Registry as `ghcr.io/think-cube/azure-pipelines-agent`.

| Tag | Meaning | Changes? |
|---|---|---|
| `X.Y.Z` | Exact release | Never |
| `X.Y`, `X`, `latest` | Newest matching release | With each release |
| `edge` | Newest build of `main` | With each merge and weekly rebuild |
| `edge-YYYYMMDD` | Weekly rebuild of `main` with current OS patches | Never |
| `sha-<commit>` | Build of one `main` commit | Never |

For production, pin a release from [Releases](https://github.com/Think-Cube/docker-azure-pipelines-agent/releases) by digest.

## Usage

```bash
docker run --rm \
  -e AZP_URL=https://dev.azure.com/<organization> \
  -e AZP_TOKEN=<personal access token> \
  -e AZP_POOL=<agent pool> \
  ghcr.io/think-cube/azure-pipelines-agent:1 --once
```

`--once` makes the agent take a single job and exit, so every job runs in a fresh container. Without it the agent keeps running until it is stopped, and removes its registration when it stops.

| Variable | Description |
|---|---|
| `AZP_URL` | Organization URL, for example `https://dev.azure.com/contoso` (required) |
| `AZP_TOKEN` | Personal access token with the **Agent Pools (read, manage)** scope |
| `AZP_TOKEN_FILE` | File with the token, instead of `AZP_TOKEN` |
| `AZP_POOL` | Agent pool (default `Default`) |
| `AZP_AGENT_NAME` | Agent name (default the container hostname) |
| `AZP_WORK` | Work directory (default `_work`) |
| `AZP_REGISTER_ONLY` | `true` registers the agent and exits, leaving it offline as a template that keeps the pool non-empty for autoscaling |

The token reaches the agent through its environment rather than its command line, so it does not show up in process listings. Jobs do not see the token variables.

## What is in the image

- The Azure Pipelines agent, in the version in the `AGENT_VERSION` build argument, verified against the SHA-256 from its release notes
- The agent package without the end-of-life Node 6, 10 and 16 task runners; tasks that still require them do not run on this agent
- `git`, `curl`, `jq`, `zip` and `unzip` on Ubuntu, in the version named on the `FROM` line of the `Dockerfile`

To add build tools, extend the image and keep its entrypoint:

```dockerfile
FROM ghcr.io/think-cube/azure-pipelines-agent:1
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
USER 10001:10001
```

The image does not include Docker. On Kubernetes, build container images with a daemonless tool such as Buildah or Kaniko, or with ACR Tasks; Microsoft notes that Docker tasks do not work on AKS, which uses containerd.

## Verify an image

```bash
cosign verify ghcr.io/think-cube/azure-pipelines-agent:<version> \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/Think-Cube/workflows/\.github/workflows/container-image\.yml@refs/tags/v.+$'
```

## Build and test locally

```bash
docker build -t azure-pipelines-agent:local .
bash tests/smoke.sh azure-pipelines-agent:local
```

The smoke test runs without Azure DevOps: it checks the non-root user, that the built-in agent starts and reports the expected version, the tools, and that the entrypoint refuses to start without its configuration.

To move to a newer agent, update `AGENT_VERSION` and both checksums in the `Dockerfile` from the agent's release notes.

## Support

Only the newest release receives fixes. `main` is rebuilt every week, and images with fixable critical vulnerabilities are not published. Report security issues through [GitHub private vulnerability reporting](https://github.com/Think-Cube/docker-azure-pipelines-agent/security/advisories/new).

## License

This project is licensed under the [MIT License](LICENSE).

## Contribution

Feel free to contribute by opening issues or pull requests. Your feedback and improvements are highly appreciated!
