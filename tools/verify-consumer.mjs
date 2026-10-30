// Install the published library in an independent module. No local path import.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const directory = process.argv[2];
const manifest = fs.readFileSync(new URL('../moon.mod', import.meta.url), 'utf8');
const version = process.argv[3] ?? manifest.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
if (!version || !/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Invalid consumer version');
if (!directory) throw new Error('Pass a NEW directory for the independent consumer');
if (fs.existsSync(directory)) throw new Error('Refusing to overwrite an existing consumer');
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(path.join(directory, 'moon.mod'), `name = "apoloe4/moonreconcile-consumer-check"
import { "apoloe4/moonreconcile@${version}" }
`);
fs.writeFileSync(path.join(directory, 'moon.pkg'), `pkgtype(kind: "executable")
import { "apoloe4/moonreconcile" @reconcile }
`);
fs.writeFileSync(path.join(directory, 'main.mbt'), `fn main {
  try {
    let source = @reconcile.Inventory::from_ids([0UL, 1UL, 2UL], scope=7UL, epoch=3UL)
    let target = @reconcile.Inventory::from_ids([0UL, 2UL, 3UL], scope=7UL, epoch=5UL)
    let config = @reconcile.Config::new(16)
    let frozen = source.snapshot(config)
    let session = @reconcile.Session::new(frozen, target.epoch(), @reconcile.SessionLimits::new())
    session.record_sent(frozen.encode()) |> ignore
    match session.receive(frozen, target.snapshot(config).encode()) {
      Complete(plan) => assert_eq(source.apply(plan).ids(), target.ids())
      _ => fail("published library did not recover exact target")
    }
    println("published ${version}: exact target verified")
  } catch { e => abort(e.to_string()) }
}
`);
for (const args of [['update'], ['check', '--deny-warn'], ['build', '--deny-warn'], ['run', '.', '--target', 'js']]) {
  const result = spawnSync('moon', args, { cwd: directory, env: process.env, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
