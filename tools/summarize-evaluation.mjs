// Pure Node standard-library reporter; no application runtime dependency.
import fs from 'node:fs';
import os from 'node:os';
const [corePath, sessionPath, baselinePath] = process.argv.slice(2);
if (!corePath || !sessionPath) throw new Error('Usage: node tools/summarize-evaluation.mjs CORE.csv SESSIONS.csv [MINISKETCH.csv]');
function read(path) {
  const lines = fs.readFileSync(path, 'utf8').trim().replace(/^\uFEFF/, '').split(/\r?\n/);
  const keys = lines.shift().split(',');
  return lines.filter(Boolean).map(line => Object.fromEntries(line.split(',').map((v, i) => [keys[i], v])));
}
const core = read(corePath), sessions = read(sessionPath);
if (!core.length || !sessions.length) throw new Error('Empty evaluation input');
if (core.some(r => !['true','false'].includes(r.complete) || !Number.isFinite(Number(r.decode_us)))) throw new Error('Invalid core row');
console.log('# 恢复率与传输成本实测\n');
console.log(`环境：${os.platform()} ${os.arch()}；CPU：${os.cpus()[0]?.model}；Node ${process.version}。`);
console.log(`\n原始样本：核心 ${core.length} 条，会话 ${sessions.length} 条。耗时是单次观察，未做稳定计时或显著性检验。`);
console.log('\n| 对称差 d | width/d | 成功/样本 | 恢复率 |\n|---|---|---|---|');
const groups = Map.groupBy(core, r => `${r.differences}:${r.ratio_twice}`);
for (const rows of groups.values()) {
  const ok = rows.filter(r => r.complete === 'true').length;
  console.log(`| ${rows[0].differences} | ${rows[0].differences === '0' ? 'width=1' : Number(rows[0].ratio_twice)/2} | ${ok}/${rows.length} | ${(100*ok/rows.length).toFixed(1)}% |`);
}
console.log('\n| 字节预算 | 成功/样本 | 成功会话双向字节范围 |\n|---|---|---|');
for (const rows of Map.groupBy(sessions, r => r.budget).values()) {
  const ok = rows.filter(r => r.complete === 'true');
  const bytes = ok.map(r => Number(r.sent_bytes) + Number(r.received_bytes));
  console.log(`| ${rows[0].budget} | ${ok.length}/${rows.length} | ${bytes.length ? `${Math.min(...bytes)}–${Math.max(...bytes)}` : '无'} |`);
}
console.log('\n成本包含已上报的实际 MRCL 收发与重试；不含网络头、对象内容或后续全量传输。失败帧也计入接收量，预算回退不表示差异不存在。');
if (baselinePath) {
  const baseline = read(baselinePath);
  const index = new Map(core.map(r => [[r.members,r.differences,r.ratio_twice,r.seed].join(':'), r]));
  for (const r of baseline) {
    if (!index.has([r.members,r.differences,r.ratio_twice,r.seed].join(':'))) throw new Error('Unmatched baseline scenario');
  }
  const expected = baseline.filter(r => Number(r.capacity) >= Number(r.differences));
  if (expected.some(r => r.verified !== 'true')) throw new Error('minisketch violated within-capacity verification');
  console.log(`\nminisketch 对照：${baseline.length} 条共同场景；容量内 ${expected.length} 条均通过精确差集核验。其裸摘要与 MRCL 帧分列，不以封装差异宣称算法优势。`);
  console.log('minisketch 驱动预先消去共同元素，只比较差集解码与摘要大小；没有测量其全量集合构建时间。矩阵仅含 d≤200、10 个种子，不能外推完整大规模矩阵。');
} else console.log('\n本次未提供 minisketch 实测输入，不输出对其性能的推断。');
