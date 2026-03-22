# Changelog

All notable changes to Post-Compact Reminder are documented in this file.

Repository: <https://github.com/Dicklesworthstone/post_compact_reminder>

This project has no tagged releases or GitHub Releases. Versions are tracked
via the `VERSION=` variable inside `install-post-compact-reminder.sh` and (when
present) the `VERSION` file.  Sections below are grouped by the version that
was active at the time of each change.

---

## [1.2.5] -- 2026-01-26 to 2026-03-11

Version bump commit: [`67f4357`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67f43570fd55e337d9e63a0de089e694ff30de75)

### Removed

- **Workaround installer deleted.** The upstream Claude Code `SessionStart`
  compact-matcher bug (anthropics/claude-code#13650) has been fixed. The
  two-hook workaround (`PreCompact` + `UserPromptSubmit` with marker file) is
  no longer needed. `install-post-compact-reminder-workaround.sh` was removed
  and the README was simplified back to the single-hook approach.
  [`8289ded`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/8289ded4f6c77c000d5a7db3b2e0914dfa8091b1)

### Fixed

- **Bash 3.2 compatibility.** Replaced all `mapfile` calls (bash 4+) with
  `while`-`read` loops so the installer works on macOS's default `/bin/bash`.
  Closes issue #1.
  [`c59a468`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c59a46874546a6434929a1ad0c7df1289c01e953)

### Changed

- **License updated** to MIT with OpenAI/Anthropic Rider, restricting use by
  OpenAI, Anthropic, and affiliates without express written permission.
  [`40fb7bc`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/40fb7bcf4d39519701c11a8703094d7659683600),
  [`1f7d0c8`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/1f7d0c8fe45f6ddf3927d54288b21c932272dd9a)

### Added

- GitHub social preview image (1280x640).
  [`caa9169`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/caa9169b2324e511672040e3b557519ba9a05bd1)

### Chores

- `.gitignore`: ignore Mac resource fork files (`._*`) and `.bv/` (beads
  viewer directory).
  [`7720689`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/7720689e4e7deb26edbf2f9a915c8190f4f4bf5c),
  [`3e8dc67`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/3e8dc6717f859c0f68c4a727497a086a43668a5f)

---

## [1.2.4] -- 2026-01-26

Version bump commit: [`2df47e5`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2df47e514511173592104f625e539ef8803e2683)

### Added

- **Workaround installer** (`install-post-compact-reminder-workaround.sh`): a
  two-hook mechanism (`PreCompact` marker + `UserPromptSubmit` injection) that
  reliably delivers the reminder when the upstream `SessionStart` compact
  matcher was broken (anthropics/claude-code#15174, #13650). Full feature
  parity with the primary installer. README updated to recommend this as the
  default.
  [`2a8a8af`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2a8a8af53d4b2d0654efa8354457f6d41e3ff970)

- **Confirmation requirement** in all message templates. Templates now use
  mandatory language ("STOP. You MUST") with numbered steps and require Claude
  to state what rules it found before proceeding. Prevents Claude from treating
  the reminder as a polite suggestion.
  [`67b1116`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67b111625647ea7f75a9d1432305d4ef0d091460)

- **Emoji polish.** Strategic emoji placement across installer output: banner
  title, section headers, status icons, completion and dry-run boxes.
  [`1841101`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/18411012f9bc481c5ca5d6941ba77e5da2d1c734)

- **Display-width-aware box drawing.** New `display_width()` and
  `pad_to_width()` functions compute actual terminal column width (emojis = 2
  columns) so bordered boxes stay aligned.
  [`e629ee9`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e629ee942fcfa6b4e0f2dfe2e3538293f02d6764)

- **Test suite expanded** with 5 new test files: `test_hook_generation`,
  `test_hook_validation`, `test_settings_add`, `test_settings_check`,
  `test_version`. CI now runs test-suite job on Ubuntu and macOS.
  [`2df47e5`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2df47e514511173592104f625e539ef8803e2683)

### Fixed

- **`BASH_SOURCE[0]` unbound variable** when installer is piped through
  `curl | bash`. Use `${BASH_SOURCE[0]:-}` default-value syntax at both usage
  sites.
  [`7aa750a`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/7aa750a0a96d528fb4a5b2e22b3d8eed5ec7a81c)

- **ANSI color output broken in `curl | bash`.** Color variables were defined
  with single quotes (`RED='\033[0;31m'`), storing literal characters instead
  of escape bytes. Switched to `$'...'` ANSI-C quoting so the escape byte is
  embedded at assignment time.
  [`e5009df`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e5009dfed7e2530229168dd3bf9a7dfee6939b1d)

- **`NO_UNICODE="false"` always disabled Unicode.** The non-empty string
  `"false"` passed the `-n` test. Fixed by initializing `NO_UNICODE=""`.
  [`fbbb73f`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/fbbb73fa6bfb5a83b64629e9a80d7db9b769414e)

- **`TEST_TEMP_DIR` nounset safety.** Initialize to empty string at module
  scope so `cleanup_test_env` does not trigger an unbound-variable error if the
  EXIT trap fires before `setup_test_env`.
  [`c3005fc`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c3005fc9b889d9bff7b222c784b77090aa112e57)

- **GitHub raw CDN caching.** Switched curl one-liner URLs from
  `raw.githubusercontent.com` (which ignores query-string cache busters) to the
  `github.com/.../raw/refs/heads/...` format.
  [`07f434a`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/07f434a4a8cf4c6e62b50e55a74197fa4b4c0516)

- **Test harness bugs.** Moved `TESTS_RUN` increment into `log_test()`;
  added `set +e` in `setup_test_env()` to prevent inherited `errexit` from
  aborting on first failed assertion; renamed `print_summary` to
  `print_test_summary` to avoid collision with the installer's 2-arg function.
  [`2df47e5`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2df47e514511173592104f625e539ef8803e2683)

### Changed

- **Hook output format overhauled.** Removed `<post-compact-reminder>` XML
  wrapper tags; output is now plain text with a `IMPORTANT` prefix and blank
  lines above/below the message. Backward-compatible parsing for legacy hooks
  with XML tags is retained.
  [`c7d79f3`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c7d79f3cfa0305d89c8fd74219303b0bdbbc0e58)

- CI test updated to match new output format (no XML tags, verify `AGENTS.md`
  reference).
  [`9843041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/9843041775dd39a5a89479a903da9944c8c2214b),
  [`c81a7ea`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c81a7ead9bfc66b2bde8cb1d9c51ee2a9b090e83)

---

## [1.2.3] -- 2026-01-26

Version bump commit: [`59c46ae`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/59c46ae06727659ce17e276e53a52610a51a2d98)

### Added

- **`--repair` / `--sync` command.** Re-syncs hook script and settings.json
  for broken or incomplete installations.
  [`f008f00`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/f008f00769c42f140cdb03b3e2b4ce8c9a770b76)

- **`--doctor` / `--self-test` command.** Battery of self-tests beyond
  `--status`: exercises the hook with various JSON inputs (compact source,
  startup source, malformed JSON, empty input) and verifies output. Supports
  `--json` for machine-readable CI output.
  [`f008f00`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/f008f00769c42f140cdb03b3e2b4ce8c9a770b76)

- **`--no-unicode` / `--plain` flag.** ASCII-only output mode for legacy
  terminals, serial consoles, or piped output.
  [`f008f00`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/f008f00769c42f140cdb03b3e2b4ce8c9a770b76)

- **Test infrastructure.** Test harness (`test_helpers.sh`) with
  `setup_test_env()`/`cleanup_test_env()`, 4 assertion functions, TAP output
  mode, and a test runner (`run_all_tests.sh`). First unit test covers
  `print_banner()` across standard, quiet, and no-color modes.
  [`0eae9ad`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/0eae9adc2ff35644179879f0a5d89bd6a4dbda1c)

- **Bash JSON fallback.** Pure-bash regex fallback for JSON parsing when `jq`
  is unavailable.
  [`59c46ae`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/59c46ae06727659ce17e276e53a52610a51a2d98)

### Security

- **Custom message injection hardening.** Escape backticks and dollar signs in
  custom messages to prevent code injection. Sanitize note field in hook script
  (strip newlines).
  [`59c46ae`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/59c46ae06727659ce17e276e53a52610a51a2d98)

- **Hook generation safety overhaul.** Replaced incomplete manual escaping with
  `printf '%q'` shell quoting. Hook output uses `printf '%s\n'` instead of
  `cat` heredoc, eliminating heredoc-boundary injection. Uses `TMPDIR` and
  per-user lock file paths for multi-user safety.
  [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547)

### Changed

- **Terminal output abstraction.** All hardcoded Unicode glyphs extracted into
  named constants (`ICON_*`, `BANNER_*`, `BULLET`, `ARROW`, `EM_DASH`).
  Progressive box-drawing degradation: double-line, single-line, ASCII.
  `apply_no_color()` and `apply_no_unicode()` mode functions. `repeat_char()`
  utility for dynamic-width borders.
  [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547)

- **Settings.json management rewrite.** Deduplicates hook entries, updates hook
  command path when it changes, detects whether a write is needed (avoids
  unnecessary backup churn), returns `updated`/`added`/`exists` status.
  [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547)

- **`do_template()` and `do_message()` simplified** via
  `require_python_for_settings` pre-flight guard.
  [`e8e09f3`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e8e09f3d58eefd31b614c3adc17b8b6f94f89f84)

- **Shell completions updated** for `--repair`, `--sync`, `--no-unicode`,
  `--plain`, `--doctor`, `--self-test`.
  [`f008f00`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/f008f00769c42f140cdb03b3e2b4ce8c9a770b76)

- **VERSION file synced** to 1.2.3 to match the installer script.
  [`e2914f8`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e2914f8754bc9a8e795676242c04a6af7a001c8a)

### Fixed

- **Output system portability.** Removed dead code and fixed edge cases in the
  output rendering pipeline.
  [`2cffab7`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2cffab756da79f01bfd1137551e3bcbc34d4f54c)

- **EXIT trap chaining.** `append_exit_trap()` now safely appends to existing
  trap handlers by parsing `trap -p` output, fixing a bug where `do_update()`
  overwrote the main `cleanup()` handler.
  [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547)

- **Half-installed state prevention.** `require_python_for_settings()` checks
  for `python3` before any file writes begin, preventing the hook script from
  being written while `settings.json` update fails.
  [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547)

---

## [1.2.0] -- 2026-01-26

Version bump commit: [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

### Added

- **GitHub Actions CI/CD.** ShellCheck linting, bash syntax validation,
  installation tests (Ubuntu + macOS), and VERSION file consistency checks.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **Release workflow.** Tag-triggered releases with SHA256 checksums, version
  validation (tag vs script vs VERSION file), and ACFS notification.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **Self-update with checksum verification.** `do_update()` now downloads from
  GitHub Releases with SHA256 verification, cache busting, bash syntax
  validation before replacement, and atomic file swap.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **VERSION file** for version tracking outside the script.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **`--message` and `--message-file` flags** for non-interactive custom message
  setting.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **`--skip-deps` flag** to suppress automatic dependency installation.
  [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b)

- **Hero illustration** (`pcr_illustration.webp`, `pcr_illustration.png`)
  added to README.
  [`b0dc6dd`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/b0dc6dda377b4d728aa7066dc1814a87d8c97527),
  [`67e1459`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67e1459c423feffb7d239e7f896e5b31865a5d2d)

- **AGENTS.md** added to version control.
  [`e60e041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e60e0417a3867e0fd548031b92c033ec79207495)

### Fixed

- **Duplicate `mkdir`** in `do_interactive`.
  [`8a9f752`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/8a9f752f6a610e7d106353ce7261b154d3f4a1b0)

### Changed

- **README completely rewritten.** Hero section, TL;DR, design philosophy,
  comparison table, full command reference, architecture diagram, message
  templates, troubleshooting, limitations, FAQ.
  [`e60e041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e60e0417a3867e0fd548031b92c033ec79207495)

- **`GITHUB_RAW_URL`** updated to point to the dedicated
  `Dicklesworthstone/post_compact_reminder` repo.
  [`e60e041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e60e0417a3867e0fd548031b92c033ec79207495)

---

## [1.1.0] -- 2026-01-26

Initial release: [`dd377cb`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/dd377cb36fe47806f7c4722ab878c7e89b485e04)

### Added

- **Core hook system.** `SessionStart` hook with `matcher: "compact"` that
  detects context compaction and injects a plain-text reminder telling Claude
  to re-read `AGENTS.md`.

- **Single-file installer** (`install-post-compact-reminder.sh`, ~1700 lines).
  Generates the hook script at `~/.local/bin/claude-post-compact-reminder` and
  configures `~/.claude/settings.json`.

- **Four message templates:** `minimal`, `detailed`, `checklist`, `default`.

- **Interactive setup mode** (`--interactive`) with custom message support.

- **Installation management:**
  - `--status` full health check
  - `--dry-run` preview mode
  - `--force` reinstall
  - `--yes` skip confirmation prompts
  - `--uninstall` / `--remove` clean removal

- **Self-update** (`--update`) from GitHub.

- **Backup/restore** for `settings.json` (`--restore`).

- **Shell completions** for bash and zsh (`--completions`).

- **Changelog display** (`--changelog`).

- **Idempotent installation.** Detects existing installs, compares versions,
  skips if already up to date.

- **Automatic dependency detection** with package-manager-aware auto-install
  for `jq` and `python3`.

- **Atomic file operations** via Python `shutil.move()` for `settings.json`
  modifications.

- **PID lock file** to prevent concurrent installer runs.

- **Environment variable overrides:** `HOOK_DIR`, `SETTINGS_DIR`.

---

## Commit Index

Full commit history in chronological order. Every commit links to its GitHub
diff.

| Date | Hash | Description |
|------|------|-------------|
| 2026-01-26 | [`dd377cb`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/dd377cb36fe47806f7c4722ab878c7e89b485e04) | Initial commit: Post-Compact Reminder for Claude Code |
| 2026-01-26 | [`e60e041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e60e0417a3867e0fd548031b92c033ec79207495) | Rewrite README and update repo URLs |
| 2026-01-26 | [`e39e61b`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e39e61bca529a8d85ab6e633ed291a674f6f862b) | Add GitHub Actions CI/CD and upgrade self-update with checksum verification |
| 2026-01-26 | [`8a9f752`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/8a9f752f6a610e7d106353ce7261b154d3f4a1b0) | Fix duplicate mkdir in do_interactive |
| 2026-01-26 | [`b0dc6dd`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/b0dc6dda377b4d728aa7066dc1814a87d8c97527) | Add hero illustration to README |
| 2026-01-26 | [`59c46ae`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/59c46ae06727659ce17e276e53a52610a51a2d98) | Harden installer security and add bash JSON fallback (v1.2.3) |
| 2026-01-26 | [`cd5a0c4`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/cd5a0c42918acce7989f6c347be0067d89748d71) | De-slopify README and add test coverage beads |
| 2026-01-26 | [`d6a0a7e`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/d6a0a7e33ee105d4e822e3c593107d3d112b9547) | Refactor terminal output, rewrite settings management, and harden hook generation |
| 2026-01-26 | [`67e1459`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67e1459c423feffb7d239e7f896e5b31865a5d2d) | Add original PNG source for hero illustration |
| 2026-01-26 | [`e8e09f3`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e8e09f3d58eefd31b614c3adc17b8b6f94f89f84) | Simplify do_template() and do_message() using require_python_for_settings |
| 2026-01-26 | [`2cffab7`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2cffab756da79f01bfd1137551e3bcbc34d4f54c) | Fix output system portability and remove dead code |
| 2026-01-26 | [`f008f00`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/f008f00769c42f140cdb03b3e2b4ce8c9a770b76) | Add --repair, --doctor, and --no-unicode CLI commands |
| 2026-01-26 | [`e2914f8`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e2914f8754bc9a8e795676242c04a6af7a001c8a) | Sync VERSION file to 1.2.3 to match installer script |
| 2026-01-26 | [`0eae9ad`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/0eae9adc2ff35644179879f0a5d89bd6a4dbda1c) | Add test infrastructure and first unit test (print_banner) |
| 2026-01-26 | [`2df47e5`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2df47e514511173592104f625e539ef8803e2683) | Fix test harness bugs and add test suite CI job |
| 2026-01-26 | [`c3005fc`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c3005fc9b889d9bff7b222c784b77090aa112e57) | Fix TEST_TEMP_DIR nounset safety and add cache busters to curl one-liners |
| 2026-01-26 | [`7aa750a`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/7aa750a0a96d528fb4a5b2e22b3d8eed5ec7a81c) | Fix BASH_SOURCE[0] unbound variable when piped through curl \| bash |
| 2026-01-26 | [`07f434a`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/07f434a4a8cf4c6e62b50e55a74197fa4b4c0516) | Switch curl URLs to non-cached GitHub path format |
| 2026-01-26 | [`e5009df`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e5009dfed7e2530229168dd3bf9a7dfee6939b1d) | Fix ANSI color output when run via curl \| bash |
| 2026-01-26 | [`fbbb73f`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/fbbb73fa6bfb5a83b64629e9a80d7db9b769414e) | Fix NO_UNICODE="false" always disabling Unicode box characters |
| 2026-01-26 | [`1841101`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/18411012f9bc481c5ca5d6941ba77e5da2d1c734) | Add emojis and polish installer output |
| 2026-01-26 | [`e629ee9`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/e629ee942fcfa6b4e0f2dfe2e3538293f02d6764) | Fix box alignment for emoji characters |
| 2026-01-26 | [`c7d79f3`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c7d79f3cfa0305d89c8fd74219303b0bdbbc0e58) | Remove XML tags, add IMPORTANT prefix and newlines |
| 2026-01-26 | [`9843041`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/9843041775dd39a5a89479a903da9944c8c2214b) | Fix test_hook to check for new message format |
| 2026-01-26 | [`2a8a8af`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/2a8a8af53d4b2d0654efa8354457f6d41e3ff970) | Add workaround installer as recommended default |
| 2026-01-26 | [`c81a7ea`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c81a7ead9bfc66b2bde8cb1d9c51ee2a9b090e83) | Update CI test to match new output format |
| 2026-01-26 | [`67b1116`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67b111625647ea7f75a9d1432305d4ef0d091460) | Add confirmation requirement to all message templates |
| 2026-01-26 | [`67f4357`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/67f43570fd55e337d9e63a0de089e694ff30de75) | Bump version to 1.2.5 |
| 2026-01-27 | [`7720689`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/7720689e4e7deb26edbf2f9a915c8190f4f4bf5c) | chore: ignore Mac resource fork files (._*) |
| 2026-02-16 | [`3e8dc67`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/3e8dc6717f859c0f68c4a727497a086a43668a5f) | chore: add .bv/ (beads viewer) to .gitignore |
| 2026-02-21 | [`caa9169`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/caa9169b2324e511672040e3b557519ba9a05bd1) | chore: add GitHub social preview image (1280x640) |
| 2026-02-21 | [`40fb7bc`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/40fb7bcf4d39519701c11a8703094d7659683600) | chore: update license to MIT with OpenAI/Anthropic Rider |
| 2026-02-22 | [`1f7d0c8`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/1f7d0c8fe45f6ddf3927d54288b21c932272dd9a) | docs: update README license references to MIT + OpenAI/Anthropic Rider |
| 2026-03-02 | [`c59a468`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/c59a46874546a6434929a1ad0c7df1289c01e953) | fix: replace mapfile with bash 3.2 compatible read loop |
| 2026-03-11 | [`8289ded`](https://github.com/Dicklesworthstone/post_compact_reminder/commit/8289ded4f6c77c000d5a7db3b2e0914dfa8091b1) | fix: remove workaround mechanism now that upstream SessionStart bug is fixed |
