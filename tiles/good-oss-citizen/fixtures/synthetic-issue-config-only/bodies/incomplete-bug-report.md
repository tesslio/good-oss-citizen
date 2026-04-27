## What's wrong

`exporter --format json` writes the file but the trailing comma after the last array element makes the output invalid JSON. Downstream `jq` fails to parse it.

## Steps

1. Run `exporter --format json --out /tmp/out.json` on the sample dataset in `tests/fixtures/sample.csv`.
2. Run `jq . /tmp/out.json`.
3. `jq` exits with `parse error: Expected another array element at line 42, column 5`.

## Version

exporter 0.4.2 on Linux.
