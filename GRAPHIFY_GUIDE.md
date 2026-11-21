# Graphify for crm-mobile

This repository has a Graphify knowledge graph in `graphify-out/` to help AI agents navigate the Flutter app.

- Start with [`graphify-out/GRAPH_REPORT.md`](graphify-out/GRAPH_REPORT.md) for the module map, major hubs, and extraction caveats.
- Use [`graphify-out/graph.json`](graphify-out/graph.json) to inspect nodes, edges, source files, and community labels programmatically.
- Open [`graphify-out/graph.html`](graphify-out/graph.html) in a browser for the interactive graph.
- For a specific feature, search the graph by its label or source path, then read the referenced source files before proposing changes. The graph is a navigation aid, not a substitute for current source code.

To refresh after source changes, run `graphify .` from the repository root. The current graph was built on 2026-11-20. See the integrity and extraction coverage notes in `GRAPH_REPORT.md` before relying on code relationships.
