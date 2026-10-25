# 核心接口与失败契约

算法接口可以独立使用：`Config → Sketch → subtract → decode`，无需 Inventory、Session、网络或数据库。需要幂等集合操作时使用 Inventory；需要计划核验时使用 Snapshot/reconcile；需要跨轮预算时使用 Session。四层共享同一纯 MoonBit 实现，无 C FFI。

## ID 与代数更新

- ID 是稳定的 UInt64，包括 0 和最大值。字符串/对象如何映射由业务决定；内容变化要换 ID 或另行核对版本。不能把截短哈希等同于绝无碰撞的对象身份。
- `Inventory::from_ids` 去重，insert/remove 幂等；有效变更增加 epoch，溢出在修改前报错。snapshot 不随 Inventory 后续变更而改变。
- `Sketch::insert/erase` 是代数更新，不维护精确成员 Map。调用方应只插入不在集合中的 ID、只删除已存在 ID；重复插入不是幂等，错误操作不保证可恢复。
- 计数更新先检查全部目标单元，溢出不会留下部分更新；subtract/decode 不修改输入。

## 参数、方向与容量

- Config 的 width 范围为 1..262144，每个表含 `3 × width` 个单元。相减双方必须使用相同 width 和 seed；配置不符返回 Incompatible。
- `remote.subtract(source)` 的正号表示远端独有、需要添加；负号表示源端独有、需要移除。反向相减会交换方向。
- `width` 不是差异恢复数量保证。哈希碰撞图可能存在不可剥离的残留，甚至较小差集也会失败；容量规划是启发式，不能用作成功概率证明。
- `decode(budget=...)` 限制恢复 ID 的 peeling 步数，范围 0..1000000；复制、初始扫描、排序等也消耗资源，不能把 steps 当成全部 CPU 指令数。width 限制约束扫描与分配规模。
- DecodeReport 允许包含部分恢复结果；仅 `complete()` 才表示全部单元归零。部分数组用于诊断，不能直接应用到业务数据。

## 核验与应用

- reconcile 仅在完整恢复并通过目标指纹核验时返回 Ready；否则返回 Retry、FullTransfer 或明确异常。Plan 字段对外不可构造，数组访问器返回副本。
- Inventory.apply 检查源 scope/epoch/指纹，先在副本中应用再核验目标；失败不修改源数据。目标 epoch 是标签，不是远端权威性证明。
- CRC、SplitMix64 类混合和集合指纹均不是身份认证。恶意对端可构造自洽内容；传输认证、对象内容校验及强集合承诺由应用处理。

## 字节与资源

- MRCL v1 快照为 `68 + 60 × width` 字节，格式仍兼容 0.1.0；不是 minisketch 二进制格式。
- DecodeLimits 在分配表前检查 width/members、长度、版本和结构。FrameReader 提供单帧分块接收，不是网络连接管理器。
- CapacityPlan 的 max_wire_bytes 是一个快照帧的预算。Session 的 max_bytes 才是驱动方记录的实际双向 MRCL 帧累计预算，含重传。
- 任何失败都不隐式下载完整清单；FullTransfer/Stopped 是建议或状态，由应用选择后续动作。

自动证据：核心与编解码测试、`exchange_wbtest.mbt`、`examples/exchange`、[完整评估](EVALUATION.md)。概率算法有限测试不等于安全证明。
