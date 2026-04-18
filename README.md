# pronto-rubycritic

[![CI](https://github.com/Rishabhs343/custom-pronto-gem/actions/workflows/ci.yml/badge.svg)](https://github.com/Rishabhs343/custom-pronto-gem/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/pronto-rubycritic.svg)](https://rubygems.org/gems/pronto-rubycritic)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2.2-ruby.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade [Pronto](https://github.com/prontolabs/pronto) runner for
[RubyCritic](https://github.com/whitesmith/rubycritic). It reports
**reek / flay / flog / complexity / churn** issues as Pronto messages —
**only on lines added or changed in the pull request**, never on untouched code.

> **New in 0.12.0** — forensic refactor: real working filters for flay/flog scores,
> safe YAML loading, GitHub/GitLab auto-detection, six independently-tested
> modules, and ≥90 % line-coverage CI gates.

---

## Table of contents

- [Why this gem](#why-this-gem)
- [At a glance](#at-a-glance)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [Configuration](#configuration)
- [Environment variables](#environment-variables)
- [CI integration](#ci-integration)
- [Architecture](#architecture)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Migrating from 0.11.x](#migrating-from-011x)
- [Contributing](#contributing)
- [License](#license)

---

## Why this gem

Running the full [RubyCritic](https://github.com/whitesmith/rubycritic) report
on every PR is **noisy** — contributors get flagged for code they never touched.
This gem scopes RubyCritic output to diff-changed lines, making it actionable:

- **Only added / modified lines are flagged.** A smell on line 42 that existed
  before the PR is silently ignored; a smell introduced by the PR on line 7 is
  reported as a Pronto message.
- **Every RubyCritic analyser is supported** — reek, flay, flog, complexity,
  churn — behind one config file.
- **Per-CI formatting.** GitHub renders HTML `<details>` blocks in PR comments;
  GitLab gets plain Markdown (detected automatically).
- **Fails loud in CI when asked, fails soft in local dev.** Set
  `PRONTO_RUBYCRITIC_RAISE_ERRORS=1` in CI to surface runner bugs; locally the
  runner degrades to an empty result set with a stderr warning.

## At a glance

| | |
|---|---|
| **Ruby** | ≥ 3.2.2 |
| **Pronto** | ≥ 0.11, < 2.0 |
| **RubyCritic** | ≥ 4.9, < 6.0 |
| **Analysers** | reek · flay · flog · complexity · churn |
| **Output modes** | GitHub HTML · GitLab Markdown · Plain |
| **Tests** | RSpec · ~60 examples · ≥ 90 % line coverage (enforced) |
| **Lint** | RuboCop · Reek · RubyCritic (self-analysis) |
| **CI** | GitHub Actions (3.2/3.3/3.4) + GitLab CI |
| **License** | MIT |

## Installation

Add to your `Gemfile`:

```ruby
gem 'pronto-rubycritic', '~> 0.12', require: false
```

Then:

```bash
bundle install
```

Or install standalone:

```bash
gem install pronto-rubycritic
```

## Quickstart

Run on the current diff:

```bash
bundle exec pronto run -r rubycritic
```

Run on the last N commits:

```bash
bundle exec pronto run -r rubycritic -c HEAD~3
```

Run against a specific commit range (CI-friendly):

```bash
bundle exec pronto run -r rubycritic --commit="origin/main" -f github_pr -c origin/main
```

### Example output

Given a PR that introduces a smell on a new line:

```text
WARNING — app/services/order.rb:42
**FeatureEnvy** — Order#calculate_total
Details:
  - Message: Order#calculate_total refers to 'customer' more than self
  - Locations: app/services/order.rb:42
  - Complexity: 14.5
  - Duplication: 0
  - Methods: 7
  - Cost: 2.1
  - Churn: 3
  - Docs: https://github.com/troessner/reek/blob/master/docs/Feature-Envy.md
```

## Configuration

Create `.rubycritic-pronto.yml` at your repo root. **All keys are optional** —
an empty file (or no file at all) reports every smell on changed lines at the
default severity.

```yaml
# Filter by reek smell type and cap total smells per module.
reek:
  smell_types:
    - FeatureEnvy
    - UncommunicativeMethodName
    - UncommunicativeVariableName
    - DuplicateMethodCall
    - LongParameterList
  max_smells: 5            # cap total smells per module (all analysers)

# Drop flay smells above this duplication-mass score.
flay:
  max_score: 100
  exclude:
    - 'spec/**/*'
    - 'db/migrate/**/*'

# Drop flog smells above this complexity score.
flog:
  max_score: 20
  exclude:
    - 'spec/**/*'

# Drop entire modules above these thresholds.
complexity:
  max: 10

churn:
  max: 5
```

### Configuration keys reference

| Key | Scope | Behaviour |
|---|---|---|
| `reek.smell_types` | reek smells only | Allow-list of reek smell type names. Non-listed reek smells are dropped. flay/flog smells are unaffected. |
| `reek.max_smells` | all smells per module | Cap total reported smells per module. |
| `flay.max_score` | flay smells only | Drop flay smells with `score > max_score`. |
| `flay.exclude` | flay smells only | Repo-relative globs (`FNM_PATHNAME`) to skip. |
| `flog.max_score` | flog smells only | Drop flog smells with `score > max_score`. |
| `flog.exclude` | flog smells only | Same as `flay.exclude`. |
| `complexity.max` | module | Drop modules with complexity > max. |
| `churn.max` | module | Drop modules with churn > max. |

### Recognised reek smell types

Use any of these under `reek.smell_types`:

```
Attribute · BooleanParameter · ClassVariable · ControlParameter · DataClump
DuplicateMethodCall · FeatureEnvy · InstanceVariableAssumption
IrresponsibleModule · LongParameterList · LongYieldList · ManualDispatch
MissingSafeMethod · ModuleInitialize · NestedIterators · NilCheck
RepeatedConditional · SelfAssignment · SingletonMethodCall · TooManyConstants
TooManyInstanceVariables · TooManyMethods · UncommunicativeMethodName
UncommunicativeModuleName · UncommunicativeParameterName
UncommunicativeVariableName · UnusedParameters · UnusedPrivateMethod
UtilityFunction
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PRONTO_RUBYCRITIC_SEVERITY_LEVEL` | `warning` | Severity of emitted messages: `info`, `warning`, `error`, or `fatal`. |
| `PRONTO_RUBYCRITIC_DEBUG` | unset | When set, prints the first 10 backtrace lines on any internal error. |
| `PRONTO_RUBYCRITIC_RAISE_ERRORS` | unset | When set, re-raises internal errors instead of returning `[]`. Recommended in CI. |
| `PRONTO_REEK_SEVERITY_LEVEL` | unset | **Deprecated.** Read for back-compat with a deprecation warning. Use `PRONTO_RUBYCRITIC_SEVERITY_LEVEL`. |

Severity can also be set in `.pronto.yml`:

```yaml
# .pronto.yml
rubycritic:
  severity_level: warning
```

Precedence: `PRONTO_RUBYCRITIC_SEVERITY_LEVEL` → `PRONTO_REEK_SEVERITY_LEVEL`
(deprecated) → `.pronto.yml` → `:warning` default.

## CI integration

### GitHub Actions

The runner auto-detects `$GITHUB_ACTIONS` and emits rich HTML with `<details>`
blocks. Example step:

```yaml
- name: Pronto
  env:
    PRONTO_PULL_REQUEST_ID: ${{ github.event.pull_request.number }}
    PRONTO_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    PRONTO_RUBYCRITIC_RAISE_ERRORS: '1'
  run: |
    bundle exec pronto run -f github_pr -c origin/${{ github.base_ref }}
```

### GitLab CI

The runner auto-detects `$GITLAB_CI` and emits plain Markdown (GitLab discussion
comments do not render `<details>` reliably). Example:

```yaml
pronto:
  stage: lint
  script:
    - bundle exec pronto run -f gitlab_mr -c origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME
  variables:
    PRONTO_GITLAB_API_PRIVATE_TOKEN: $PRONTO_GITLAB_TOKEN
    PRONTO_RUBYCRITIC_RAISE_ERRORS: '1'
```

### Output differences table

| Feature | GitHub Actions | GitLab CI | Local CLI |
|---|---|---|---|
| Markup | HTML `<details>` | Plain Markdown | Plain Markdown |
| Location links | Autolinked | Plain text | Plain text |
| Detected via | `$GITHUB_ACTIONS` | `$GITLAB_CI` | neither |

## Architecture

```
Pronto::RubyCritic (Runner)
├── ConfigLoader     — safe YAML + severity resolution
├── Analyser         — owns ::RubyCritic::Config global, runs AnalysersRunner
├── SmellFilter      — pure filter against user config
├── MessageBuilder   — maps smells → Pronto::Message on added lines
└── Formatter        — GitHub HTML / GitLab Markdown / Plain
```

Each module has its own spec file (`spec/pronto/rubycritic/*_spec.rb`) and
mocks only the boundary between layers. Integration tests in
`spec/integration/` exercise the full runner end-to-end against real fixtures.

See [CHANGELOG.md](CHANGELOG.md) for the rationale behind every change in 0.12.0.

## Development

```bash
git clone https://github.com/Rishabhs343/custom-pronto-gem.git
cd custom-pronto-gem
bundle install

bundle exec rake              # RuboCop + RSpec
bundle exec rake ci           # RuboCop + Reek + RSpec + RubyCritic (full CI)
bundle exec rake reek         # Reek only
bundle exec rake critic       # RubyCritic self-analysis
```

Run a single spec file:

```bash
bundle exec rspec spec/pronto/rubycritic_spec.rb
```

Generate a coverage report (opens `coverage/index.html`):

```bash
COVERAGE=1 bundle exec rspec
```

Debug the runner against a real project:

```bash
cd /path/to/your/project
PRONTO_RUBYCRITIC_DEBUG=1 bundle exec pronto run -r rubycritic --unstaged
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `no messages reported, but smells exist` | You set the now-removed `reek.min_severity` key | Remove it from `.rubycritic-pronto.yml`; see [migration](#migrating-from-011x) |
| `undefined method new_file? for Pronto::Git::Patch` | Running a test that was written against ≤ 0.11.x mocks | Upgrade test mocks to use `instance_double(Pronto::Git::Patch)` |
| `invalid YAML in .rubycritic-pronto.yml` on stderr, no messages | Config file has a syntax error | Run `yamllint .rubycritic-pronto.yml` or check your editor's linter |
| `pronto-rubycritic: PRONTO_REEK_SEVERITY_LEVEL is deprecated…` | Legacy env var still set | Switch to `PRONTO_RUBYCRITIC_SEVERITY_LEVEL` |
| All smells reported as `:warning` regardless of config | Default severity is `:warning` in 0.12.0 | Set `severity_level: info` in `.pronto.yml` under `rubycritic:` |
| `RubyCritic::SourceControlSystem::NotFoundError` in CI | Working dir is not a git repo | Ensure `actions/checkout@v4` uses `fetch-depth: 0` |

Set `PRONTO_RUBYCRITIC_DEBUG=1` for the first 10 lines of any backtrace.

## Migrating from 0.11.x

| Change | Action needed |
|---|---|
| `reek.min_severity` removed | Delete the key from `.rubycritic-pronto.yml`. It was dead code that silently filtered out every smell. |
| `flay.max_score` / `flog.max_score` now actually filter | Expect more accurate filtering — previously these keys were no-ops. |
| Default severity `:info` → `:warning` | To keep `:info`, set `PRONTO_RUBYCRITIC_SEVERITY_LEVEL=info` or add `rubycritic.severity_level: info` to `.pronto.yml`. |
| `PRONTO_REEK_SEVERITY_LEVEL` deprecated | Rename to `PRONTO_RUBYCRITIC_SEVERITY_LEVEL`. The legacy var still works with a deprecation warning. |
| `Pronto::RubyCritic::VERSION` added | Existing `Pronto::RubyCriticVersion::VERSION` still works. |
| `rubycritic` dependency now pinned `< 6.0` | If you pin RubyCritic 6.x in your own `Gemfile`, wait for pronto-rubycritic 0.13. |

Full breaking-change rationale in [CHANGELOG.md](CHANGELOG.md).

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-thing`)
3. Make your changes with tests
4. Run the full CI suite locally: `bundle exec rake ci`
5. Open a PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for more detail. All contributions must
pass RuboCop, Reek, RSpec with ≥ 90 % line coverage, and RubyCritic ≥ 90 score.

## License

[MIT](LICENSE) © Rishabh Singh. See [LICENSE](LICENSE) for the full text.
