# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] — 2026-04-18

Major forensic refactor. **Breaking changes** — see migration notes below.

### Added
- `PRONTO_RUBYCRITIC_SEVERITY_LEVEL` environment variable (preferred).
- `PRONTO_RUBYCRITIC_DEBUG` for verbose error output (prints backtrace head).
- `PRONTO_RUBYCRITIC_RAISE_ERRORS` to fail fast in CI instead of swallowing errors.
- GitHub Actions / GitLab CI auto-detection via `Pronto::RubyCritic::Formatter`.
  GitHub gets HTML `<details>` blocks; GitLab gets plain Markdown.
- `flay.max_score`, `flog.max_score`, `flay.exclude`, `flog.exclude` now map to
  real `Smell#analyser` / `Smell#score` fields and actually filter smells.
- Internal modules: `ConfigLoader`, `Analyser`, `SmellFilter`, `MessageBuilder`,
  `Formatter`. Each has its own test file.
- `.gitignore`, `Rakefile`, `.reek.yml`, `.rubycritic.yml`, `.gitlab-ci.yml`.
- Convenience `Pronto::RubyCritic::VERSION` alongside
  `Pronto::RubyCriticVersion::VERSION`.

### Changed (breaking)
- Default severity level: `:info` → `:warning`.
  Rationale: `:info` messages are often ignored in Pronto reports.
- `rubycritic` dependency: `>= 4.9, < 6.0` (was unpinned).
- `pronto` dependency: `>= 0.11, < 2.0` (was `~> 0.11`).
- `File.fnmatch` exclude patterns now use `FNM_PATHNAME | FNM_DOTMATCH` and
  are matched against repo-relative paths (absolute paths never matched before).

### Removed
- `reek.min_severity` config key. RubyCritic's `Smell` has no `severity` field
  (only `status`, `score`, `cost`), so the previous implementation silently
  filtered out *every* smell whenever this key was set.
  **Migration:** use `reek.smell_types` to allow-list specific smell types, or
  `flay.max_score` / `flog.max_score` for score-based filtering.

### Fixed
- `reek.min_severity` silently dropping every smell (dead code).
- `flay.max_score` / `flog.max_score` never matching any module (dead code —
  `AnalysedModule` has no `flay_score` / `flog_score` attributes).
- `File.fnmatch` exclude patterns silently never matching due to absolute path.
- Unbounded `YAML.load_file` on user config (now `YAML.safe_load_file` with an
  explicit permitted_classes list — defence in depth against CVE-style YAML
  RCE vectors on older Psych versions).
- Env var typo: `PRONTO_REEK_SEVERITY_LEVEL` is now read with a deprecation
  warning; `PRONTO_RUBYCRITIC_SEVERITY_LEVEL` is the canonical name.
- Broad `rescue StandardError` now emits class name + message, and prints
  backtrace head when `PRONTO_RUBYCRITIC_DEBUG` is set.
- `patch_for_smell` O(N·M) scan replaced with pre-built hash index.
- `smell.message.capitalize` crash on nil message.
- GitLab comments no longer show literal `&nbsp;` entities and unrendered
  `<details>` blocks.

### Migration from 0.11.x
- If you use `reek.min_severity` in `.rubycritic-pronto.yml`, remove it. It
  never worked; removing it will restore visibility into your smells.
- If you use `flay.max_score` or `flog.max_score`, no action needed — they now
  actually filter (previously were a no-op).
- If you rely on the default severity being `:info`, set
  `severity_level: info` under the `rubycritic:` key of `.pronto.yml` or export
  `PRONTO_RUBYCRITIC_SEVERITY_LEVEL=info`.
- If you import `Pronto::RubyCriticVersion::VERSION`, no change required — it
  is preserved. `Pronto::RubyCritic::VERSION` is a new equivalent.

## [0.11.1] and earlier
See git history (`git log --oneline lib/pronto/rubycritic.rb`).
