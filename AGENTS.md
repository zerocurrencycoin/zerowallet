# Agent Instructions - Zerowallet

## General

This section is identical in every ZK repository.

- **Git:** No `Co-authored-by:` or attribution trailers.
- **Files:** No removal, destructive overwrite, or new file without explicit user confirmation.
- **Shell:** Run commands and scripts with bash (`bash -c`, `bash -s <<'EOF'`, `#!/usr/bin/env bash`); zsh does not split an unquoted variable into words. Redirect `zerod -daemon` output to a file; a pipe or captured output blocks until the node stops.
- **Comments:** State current behavior and why: tricky implementation details and special considerations. No tracking IDs (including upstream PR and issue numbers), status notes, change history, or references to documents in code, tests, scripts, or help text; a fix's history belongs in the commit message and release notes. Code imported from another project keeps its text.
- **Documents:** One home per fact: merge into the existing section, delete copies, and remove moved content from its source. Every sentence states a fact, a decision, or an action. Decisions and their status live in the project's documents. No parentheticals in headings. Cite code by file, function, and search token, never by line number.
- **Decisions:** A proposal stays proposed until the user decides it; never list it as a step. A postponed item lives in its one TODO entry with every detail needed to resume it; no branches, scripts, or sections for it. Documents carry no role markers ("Maintainer"): one team decides and changes everything.
- **Directions:** Before giving build, release, or test steps, read the scripts and their documented options and use what they already do; give short numbered steps with one command per line and no comments. Before a run longer than about 5 minutes, with many threads, or with a large download, measure one small instance and confirm the exact parameters with the projected time and memory.

## Zerowallet

- **Start:** README.md, BUILD.md. Desktop wallet only; the node is the Zero repository.
- **Scripts:** Build, release, and package checks go through `src/scripts` (`mkdev`, `mkrelease`, `package-verify`, `ftest`); script changes follow `src/scripts/Bashrules.md`.
- **Test ports:** A mainnet `zerod` may run on the host on P2P 23801 and RPC 23811; a test `zero.conf`, including one the wallet generates, uses other ports.
