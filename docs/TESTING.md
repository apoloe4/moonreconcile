# 验证记录与复现

验证环境：2026-10-04，Windows，moon 0.1.20260920，moonc v0.10.14。无项目外部依赖。

## 本地测试

```sh
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
moon test --target wasm --deny-warn
moon test --target js --deny-warn
moon fmt --check
moon info
moon run examples/basic
moon run examples/partitioned
moon run examples/capacity
```

默认 wasm-gc、wasm 和 js 测试在本地验证；native 在本机缺少 cc/gcc/clang，未能执行 native 编译测试，不表述为全目标本地通过。CI 配置包含 Ubuntu native 目标，远端执行状态需在上传后确认。

## 测试证据

- 基础算法：空表、UInt64 零和最大值、正负差异、插入删除抵消、三分带索引、不修改原表、计数溢出原子性和配置兼容性。
- 容量：不足时保留 residual，不误报完整；恢复步数预算、加倍重试、策略上限与全量回退。
- 正确性对照：100 组生成式重叠集合与精确差集比较；不同 seed；差集逆方向；加入大量共同元素后结果不变。
- 本地计划：去重、幂等变更、epoch 溢出、过期计划、目标指纹修改、无效增删及失败不修改源集合；黑盒公开 API 测试覆盖防御性数组副本与快照隔离。
- 二进制格式：标准 CRC 向量、规范往返、逐字节损坏、全部截断位置、重签 CRC 后的结构损坏、资源限制与500组确定性随机字节输入。
- 流接收：不同碎片长度、尾随字节、截断 EOF、早期拒绝恶意宽度声明、错误失效与重置。
- 分区：只请求变化分区、任意桶请求顺序、幂等重传、过期 offer、不完整收集拒绝全局计划、整体变更预算与单次/批量摘要一致性。

确定性生成测试不是统计独立的成功率估计，也不等同安全审计。只做测试中覆盖到的有限输入判断。

## 可复现传输量示例

`moon run examples/partitioned` 使用 ID 0..9999，删除123，加入20000，64分区，起始 width=4。检查恢复后的集合精确等于目标集合，并输出接收清单和摘要字节数。示例统计不会把实际对象大小算作节省的数据。

本次输出：清单1604字节，摘要616字节，远端全量ID数组80000字节；基础及容量示例也包含断言。尚未提供吞吐、时延和不同差异率的完整基准，不作生产性能承诺。

## CI

`.github/workflows/ci.yml` 检查、构建、测试 wasm-gc/wasm/js/native，并运行三个示例；另一个 job 检查格式和生成接口是否与提交一致。CI 采用官方工具链安装脚本，升级工具链可能揭示 API 或语法变化。
