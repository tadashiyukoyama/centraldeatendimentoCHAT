# Frontend-tests diagnosis

## Evidence

Previous PR run: `29563348750`, job `frontend-tests` (`87830390554`).
The job failed in `Run frontend tests`; `lint-frontend` and all backend jobs
passed. The result was 2 failed tests, 376/377 files passed, and 3738/3740
tests passed.

The next PR run after the workspace commit was `29565262635`. Its exact failed
job remained `frontend-tests`, in the `Run frontend tests` step. Its
`lint-frontend` and all backend jobs passed.

## Exact failure

The affected test file is:

`app/javascript/dashboard/routes/dashboard/onboarding/specs/inbox-setup/InboxChannelsDialog.spec.js`

The two failed tests were:

- `opens the Facebook page picker when fbAppId is configured`;
- `shows the grid (not the picker) when fbAppId is missing`.

Both runs ended with the same Vitest message:

```text
[vitest] No "useStore" export is defined on the "dashboard/composables/store" mock. Did you forget to return it from "vi.mock"?
```

The causal chain is unchanged: the test mock exports `useMapGetter`, while the
component path reaches `useAccount.js`, which imports and calls `useStore`.

The new run also logged this ancillary sourcemap error before the tests:

```text
Error: An error occurred while trying to read the map file at index.es.js.map
Error: ENOENT: no such file or directory, open '.../@chatwoot/prosemirror-schema/dist/index.es.js.map'
```

It did not replace the failing job or change the terminal `useStore` failure.
The current failure is therefore the same failure as the previous run.

## Scope decision

No related product file was changed by this PR. The comparison against the
authorized base contains no changes under `app/`, `enterprise/`, or `spec/`,
and no changes to `InboxChannelsDialog`, `useAccount`, or `useChannelConfig`.
This document is diagnosis only; the frontend mock remains out of scope for
this PR.

The CI run was observed after the new commit and was not manually rerun.
