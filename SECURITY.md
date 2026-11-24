# Security Policy

## Supported Versions

Security fixes are released only for the latest version of Mac AI Helper.
The App updates itself, or you can download the latest version from
[Releases](https://github.com/akazakou/mac-ai-helper/releases/latest).

## Reporting a Vulnerability

Please do **not** open a public issue for a security problem.

Report it privately through
[GitHub private vulnerability reporting](https://github.com/akazakou/mac-ai-helper/security/advisories/new).
Only the maintainers can see the report.

Include in the report:

- the App version and the macOS version
- the steps to reproduce the problem
- the impact: what an attacker can read, change or run

Reports are handled on a best-effort basis. When a fix is released, the report is
published as a security advisory and you are credited, unless you ask not to be.

## Out of Scope

- API keys are stored in a plain file that only your macOS user account can read.
  This is documented in [PRIVACY.md](PRIVACY.md) and is not a vulnerability.
- Problems in the AI providers' services (OpenAI, Anthropic, Google, OpenRouter).
  Report those to the provider.
