# Retool agent plugins

This repository contains the public distributions of Retool's agent plugins.

## Packages

| Path | Platform | Distribution |
| --- | --- | --- |
| [`claude/`](claude/) | Claude Code and Cowork | Anthropic plugin directory or organization upload |
| [`openai/`](openai/) | ChatGPT and Codex | OpenAI Platform plugin portal |

The OpenAI files in this repository are a public release record. OpenAI
publication still happens through the OpenAI Platform.

## Repository policy

- Do not edit generated plugin files by hand.
- Each release must identify the plugin version.
- Commit unpacked plugin directories so changes can be reviewed.
- Attach generated zip files to GitHub Releases rather than committing them.
- Never commit credentials, customer data, private Retool URLs, or deployment
  challenge tokens.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the release contribution process.

## Support

For product support, visit [Retool Support](https://retool.com/support).

For security issues, follow [SECURITY.md](SECURITY.md).
