# Architecture Diagrams

## `cloudmart-architecture.mmd` / `cloudmart-architecture.png`

The final CloudMart target architecture — diagram-as-code in [Mermaid](https://mermaid.js.org/), which GitHub renders natively in any Markdown file (including directly in [README.md](../README.md)). The `.png` is a rendered export of the same source, for anywhere Mermaid isn't supported (e.g. a resume PDF, LinkedIn).

**Status is shown via label text, not color alone** — every node carries an explicit `[DEPLOYED]`, `[PLAN-VALIDATED]`, or `[VALIDATED, DESTROYED]` tag; color is a secondary visual aid on top of that, not the only signal. See [docs/architecture.md](../docs/architecture.md) for the prose version of the same information, and the individual ADRs in [docs/decisions/](../docs/decisions/) for the reasoning behind each status.

**Regenerating the PNG after editing the `.mmd` source** (uses [`@mermaid-js/mermaid-cli`](https://github.com/mermaid-js/mermaid-cli), free/open-source, run via `npx` — no install, no paid dependency):
```bash
npx -y @mermaid-js/mermaid-cli \
  -i diagrams/cloudmart-architecture.mmd \
  -o diagrams/cloudmart-architecture.png \
  -b white --size 1600
```
(`--size` replaced the older `-w` flag in mermaid-cli v12; the last render used v12.0.0.)
