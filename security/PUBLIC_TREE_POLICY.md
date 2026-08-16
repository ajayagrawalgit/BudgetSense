# Public Git Initialization Policy

BudgetSense has no Git history as assessed. This repository must be initialized as a public tree only after the owner runs the post-initialization verifier.

## Never add

- Android keystores, `key.properties`, provisioning profiles, certificates, private keys, signing passwords, tokens, or `.env` files.
- Customer databases, backups (`.bsbak`), exports, logs, screenshots, coverage, build artifacts, symbol files, source maps, or local tool caches.
- Generated `.dart_tool`, `build`, platform build directories, or local virtual environments.

## Before the first commit

1. Confirm `BUDGETSENSE_KEYSTORE_PROPERTIES` points outside the checkout and has mode `0600`.
2. Run `./scripts/security/validate_gitignore_policy.sh`.
3. Run `git init`, stage deliberately, then run `./scripts/security/verify_after_git_init.sh` before committing.
4. Pin every GitHub Action to a reviewed immutable full SHA, with a comment naming the reviewed release. Existing workflow tags are intentionally treated as a blocker until converted.
5. Run Gitleaks against the initial history, inspect every result with redaction, and remove generated/local artifacts before publication.

No private material was moved into this policy or any report.
