# ADR-0031: Prose linting with vale

- **Status:** Accepted
- **Date:** 2026-08-19
- **Deciders:** Otto

## Context

The house prose style lives in `~/.claude/prose.md`, and its word-level subset is
encoded as [vale](https://vale.sh) rules under `~/.claude/vale/styles/Prose`.
Those rules were already enforced in `~/.claude` itself and in
`~/personal-website`; `agpalindrome/claude#21` tracks extending them to the
remaining repos, and this ADR records how `ferric-fred` takes them.

Four constraints came with the shared rules, each settled upstream:

- **Errors block, warnings do not.** vale's exit code counts errors only,
  whatever `MinAlertLevel` says, so the split needs no flag.
- **`--no-global` is required.** Without it vale merges a machine-global styles
  directory on top of the repo's own, and a contributor's local run stops
  agreeing with CI.
- **Scope is a decision, not a default.** Generated files and vendored code are
  not authored prose, and a linter is the wrong authority over published writing
  whose voice belongs to its author.
- **An empty file list must fail.** `xargs vale` with no path arguments lints
  empty stdin, reports zero errors and exits 0 — a green check over nothing.
  That bug shipped into `~/.claude`'s own CI once.

The rules are vendored rather than referenced. A machine-global styles directory
is invisible to CI and to contributors, and a `vale sync` package needs a public
host, which the private `agpalindrome/claude` cannot be.

## Decision

We will lint the repo's authored markdown with vale, as a CI step calling a
script that also runs locally.

- **`.vale.ini` and `.vale/styles/`** are vendored copies, written and re-checked
  by `~/.claude/scripts/sync-vale.sh` (`--check` reports drift without writing).
  They are not edited here — a rule that fights real writing is a finding for
  `~/.claude`, not a local override.
- **`scripts/prose-lint.sh`** holds the scope filter, the empty-list assertion
  and the `--no-global` invocation, so one file is the source of truth for what
  the gate does and the same code runs locally and in CI. This follows the
  precedent `scripts/bench-ci.sh` set: a real file, never an inline
  `bash -c` block (`repo-settings.yml` records why).
- **`ci.yml` gains a step** calling that script through `nix develop`, alongside
  fmt, clippy, tests and `cargo deny`. This repo's flake supplies every CI tool
  (ADR-0008), so vale joins the dev shell rather than being downloaded by the
  workflow.
- **vale is pinned to 3.17.1** through a second, dedicated `nixpkgs-vale` flake
  input. The main `nixpkgs` pin currently carries vale 3.15.1, and bumping it for
  the linter alone would move the Rust toolchain with it. 3.17.1 is the version
  `~/.claude`'s CI pins and the version the shared rules' blockquote handling was
  measured against.

**Scope.** Every tracked `*.md` file except the per-crate `CHANGELOG.md`, which
release-plz generates from commit subjects (ADR-0012) — those are not authored
here, and an edit to one is overwritten at the next release. Rust doc comments
stay out: `.vale.ini` carries a `[formats] rs = md` alias, but it is inert
without an `[*.rs]` section, and extending the gate to rustdoc is a separate
decision rather than a side effect of this one. Nothing in this repo is prose
whose voice belongs to its author in the sense the shared rules carve out — there
is no blog, no CV, no marketing copy — so the ADR log, the READMEs and
`CONTRIBUTING.md` are all in scope.

## Consequences

- New and edited prose meets the same word-level standard as the sibling repos,
  checked rather than remembered.
- The gate is only as good as the vendored copy. A stale `.vale/styles` is
  indistinguishable from a live one from inside this repo, so re-sync before
  reporting a rule as broken: `~/.claude/scripts/sync-vale.sh --check .`.
- CI pays a second nixpkgs evaluation. The fetch is cached, and the cost buys a
  linter version that moves independently of the compiler.
- Adoption flagged existing ADR prose. Four misspellings against the Oxford
  British convention were corrected as typo fixes, which the append-only ADR rule
  permits. Five word-choice flags — three `really`, one `very`, one `simply` —
  were left for the owner, because rewriting settled prose to satisfy a linter is
  the failure mode this gate is supposed to avoid, not an instance of it.
- The `simply` flag is a finding for `~/.claude`. `Prose.Condescending` reports
  that `simply` "tells a stuck reader the thing is easy", and at
  `0030-l2-testing-stance-proptest-adopt-or-decline.md:114` the word means
  *merely*. `Prose.Merely` already draws exactly this distinction for `just` and
  demotes it to a warning; `Prose.Condescending` has no matching carve-out.

## Alternatives considered

- **A `nix flake check` derivation.** The natural shape where a repo's gates live
  in the flake — but this repo's do not. `flake.nix` exposes a dev shell and a
  formatter, and `ci.yml` runs each gate as an explicit step through
  `nix develop`. Adding a lone check output would have made vale the only gate
  runnable by `nix flake check`, which reads as the start of a migration nobody
  decided on.
- **A `pre-commit` hook.** The tracked hook is a secret guard (ADR-0014), and the
  correctness gates deliberately live in CI rather than in it. A prose error at
  commit time also blocks the commit that would fix it.
- **Downloading vale in the workflow**, as `~/.claude`'s CI does. Rejected
  because vale is in nixpkgs: the two tools this repo does download
  (`release-plz`, `bencher`) are downloaded precisely because they are not, and
  a downloaded binary would leave contributors with no local runner.
- **vale from the existing `nixpkgs` pin.** One input rather than two, but it
  supplies 3.15.1 — behind the version the shared rules were measured against,
  and behind the sibling repos.
