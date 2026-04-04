# Codex auth.json detection design

## Summary

Add support for mounted Codex authentication state by detecting `/home/codex/.codex/auth.json` at container startup. When that file is present, the container should allow Codex to use its existing auth flow without requiring `OPENAI_API_KEY`. When it is absent, the current `OPENAI_API_KEY` requirement remains in place.

## Scope

This change affects:

- `base/entrypoint.sh`
- `codex-monitor/entrypoint.sh`
- `tests/regression.sh`
- `README.md`

This change does not affect:

- Dockerfile contents
- GitHub authentication behavior
- monitor token behavior
- interactive behavior in `codex-monitor` beyond auth-file detection if daemon mode is used

## Goals

- Support Codex authentication via a mounted `auth.json` file
- Keep `OPENAI_API_KEY` as a fallback for existing workflows
- Avoid introducing new environment variables or file-copy behavior
- Document the mount path and example usage clearly

## Non-goals

- Copying auth files into the image or container filesystem
- Supporting alternate auth file paths
- Replacing or changing `GITHUB_TOKEN` handling
- Changing daemon token requirements for `codex-monitor`

## Expected auth file path

The standard auth file path for the `codex` user inside these containers is:

`/home/codex/.codex/auth.json`

Users will provide this file by bind-mounting their existing host-side Codex auth file to that exact path, preferably read-only.

## Runtime behavior

### `codex-base`

On startup, `base/entrypoint.sh` will:

1. Preserve the existing Git identity setup.
2. Check whether `/home/codex/.codex/auth.json` exists and is a regular file.
3. If the file exists, skip the `OPENAI_API_KEY` requirement.
4. If the file does not exist, require `OPENAI_API_KEY` exactly as today.
5. Continue requiring `GITHUB_TOKEN` and running `gh auth login --with-token` exactly as today.
6. Continue supporting only `MODE=interactive`.

### `codex-monitor`

In `MODE=daemon`, `codex-monitor/entrypoint.sh` will:

1. Preserve the existing Git identity setup.
2. Check whether `/home/codex/.codex/auth.json` exists and is a regular file.
3. If the file exists, skip the `OPENAI_API_KEY` requirement.
4. If the file does not exist, require `OPENAI_API_KEY` exactly as today.
5. Continue requiring `GITHUB_TOKEN` exactly as today.
6. Continue requiring `CODEX_MONITOR_TOKEN` for non-local daemon binds exactly as today.
7. Continue launching the daemon exactly as today.

In `MODE=interactive`, behavior remains unchanged.

## Auth precedence

Authentication precedence is intentionally simple:

1. If `/home/codex/.codex/auth.json` is present, Codex auth is considered available and `OPENAI_API_KEY` is not required.
2. If `/home/codex/.codex/auth.json` is absent, `OPENAI_API_KEY` is required.
3. If neither is available, startup fails with the existing missing-key error.

No extra configuration is added to choose between these paths.

## Error handling

- Presence of `auth.json` suppresses only the `OPENAI_API_KEY` requirement.
- Missing `GITHUB_TOKEN` should still fail in the same modes where it currently fails.
- Missing `CODEX_MONITOR_TOKEN` for non-local daemon binds should still fail exactly as it does today.
- The existing missing `OPENAI_API_KEY` error message can remain unchanged because it still applies when no auth file is mounted.

## Testing

Regression coverage should verify:

- base entrypoint does not require `OPENAI_API_KEY` when `auth.json` is present
- base entrypoint still requires `OPENAI_API_KEY` when `auth.json` is absent
- monitor daemon mode does not require `OPENAI_API_KEY` when `auth.json` is present
- existing monitor token enforcement still works
- existing unrelated regression checks still pass

Tests should use temporary directories and stubbed binaries, following the current shell-based regression style.

## Documentation changes

`README.md` should be updated to:

- state that Codex can authenticate either through a mounted `auth.json` file or `OPENAI_API_KEY`
- describe `/home/codex/.codex/auth.json` as the in-container mount target
- include `docker run` examples that mount the file read-only
- explain that `OPENAI_API_KEY` is only required when the auth file is not mounted
- keep existing API-key examples for users who do not have an auth file

Recommended mount example:

```bash
-v "$HOME/.codex/auth.json:/home/codex/.codex/auth.json:ro"
```

## Implementation notes

- The change should stay minimal and local to current entrypoint validation logic.
- The auth-file check should use a regular-file existence test.
- Documentation should avoid implying that the container copies or manages the auth file.

## Risks

- If Codex changes its default auth file location in the future, this mount path would need to be updated.
- Users may assume directory mounts are equivalent; the documentation should be explicit that the file path itself is mounted to the exact target path.

## Success criteria

- A user can run either image with a read-only mount to `/home/codex/.codex/auth.json` and no `OPENAI_API_KEY`.
- Existing API-key-based workflows continue to work unchanged.
- README examples make the auth-file workflow discoverable and unambiguous.
