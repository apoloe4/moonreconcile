// Project baseline is the compiler actually verified for this source format.
// It also exceeds the contest's moonc >= 0.10.16 requirement.
import { spawnSync } from 'node:child_process';
const minimum = [0, 10, 17];
const result = spawnSync('moonc', ['-v'], { encoding: 'utf8' });
if (result.error || result.status !== 0) {
  console.error('Cannot run moonc. Install the official MoonBit toolchain and add it to PATH.');
  process.exit(1);
}
const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
const match = output.match(/^\s*(?:moonc\s+)?v?(\d+)\.(\d+)\.(\d+)/m);
if (!match) {
  console.error('Unrecognized moonc version output; cannot verify the acceptance baseline.');
  process.exit(1);
}
const actual = match.slice(1, 4).map(Number);
const firstDifference = actual.findIndex((v, i) => v !== minimum[i]);
if (firstDifference !== -1 && actual[firstDifference] < minimum[firstDifference]) {
  console.error(`moonc ${actual.join('.')} is too old: this project requires >= ${minimum.join('.')}.`);
  process.exit(1);
}
console.log(`moonc ${actual.join('.')} satisfies project >= ${minimum.join('.')} and contest >= 0.10.16.`);
