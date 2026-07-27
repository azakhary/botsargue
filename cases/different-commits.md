# Protocol mechanics test: different commits, both locally correct

This is a reproducible one-operator protocol test. Two isolated coding-agent
processes were given separate Git worktrees at different commits. It is not a
two-coworker customer case and does not prove cross-person adoption.

The question was:

> Does `parseLimit(0)` succeed in the implementation you were given?

The parent commit,
`fe8bac531ae0105589483fa8c731aa21ea4e6b4f`, accepts zero. Its child,
`5c6083b83d339e99773605ff5e94d8ad63198948`, changes the guard from
`parsed < 0` to `parsed <= 0` and rejects zero with a `RangeError`.

Both isolated agents ran their repository tests and direct runtime checks.
They then cross-checked the commit relationship and ratified `BOTH_CORRECT`:
each opening was correct for the exact checkout it described.

## Reproduce the evidence

The complete two-commit history is preserved as
[`different-commits/fixture.bundle`](different-commits/fixture.bundle).

SHA-256:

```text
7936d306b591087e559610ea5b5c76c8c4dcbc160c6b6ef8b8be374b5f471d52
```

Clone it and inspect both revisions:

```bash
git clone cases/different-commits/fixture.bundle different-commits
cd different-commits
git log --oneline --all --graph
git diff fe8bac531ae0105589483fa8c731aa21ea4e6b4f \
  5c6083b83d339e99773605ff5e94d8ad63198948 \
  -- parse-limit.js parse-limit.test.js
```

At the parent revision:

```bash
git switch --detach fe8bac531ae0105589483fa8c731aa21ea4e6b4f
npm test
node --input-type=module -e \
  'import { parseLimit } from "./parse-limit.js"; console.log(parseLimit(0))'
```

At the child revision:

```bash
git switch --detach 5c6083b83d339e99773605ff5e94d8ad63198948
npm test
node --input-type=module -e \
  'import { parseLimit } from "./parse-limit.js"; try { console.log(parseLimit(0)) } catch (error) { console.log(error.name, error.message) }'
```

This case proves a narrow mechanism: isolated agents can surface
revision-scoped evidence and ratify a conditionally correct settlement.
BotsArgue did not decide which implementation was “true,” and this fixture
must not be presented as evidence that two coworkers used the product.
