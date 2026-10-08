# JOB object ID release regression

This browser test compiles the real `JOB_Browser` unit with pas2js. A WASM
export fixture records allocator/releaser calls and maintains its own free
list. The test exercises object registration, release, and reuse through
the bridge for 20 cycles, and rejects a missing release export.

Before the fix, the first release calls the allocator again, never returns
the original ID to the free list, and fails the test. The fixture does not
inspect the implementation or depend on the generated JavaScript's text.

From the repository root, with a complete checkout and a built pas2js
compiler (as described in the repository README):

```sh
bin/x86_64-linux/pas2js -Jicompiler/utils/pas2js/dist/rtl.js packages/job/tests/testrelease.lpr
python3 -m http.server 8000 --directory packages/job/tests
```

If FPC sources are outside `compiler`, replace the `-Ji` path with their
`utils/pas2js/dist/rtl.js` path.

Open `http://localhost:8000/testrelease.html`. Success displays:

```text
PASS: 20 release/reuse cycles and missing release export
```

For automated headless verification, install Python Playwright and a
Chromium browser, then run:

```sh
python3 packages/job/tests/run_release.py --chromium /usr/bin/chromium
```

The runner serves the compiled test on a temporary localhost port. Supply
`--chromium` when using a system browser; otherwise it uses Playwright's
installed Chromium. Generated JavaScript is already ignored by the repository.

These regression sources use the JOB package's modified LGPL terms; see
the repository's `LICENSE` and `COPYING.txt`.
