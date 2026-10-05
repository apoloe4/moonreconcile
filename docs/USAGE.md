# 接入指南

## 选择输入模型

使用稳定 `UInt64` ID。业务自增 ID 可以直接使用；若使用内容哈希，请在业务层保留完整摘要以核验内容，并评估截断到 64 位导致的碰撞风险。同一 ID 的不同内容不属于本库可检测的集合差异。

`Inventory::from_ids` 会去重，并构建精确 Map。`ids()`、`Plan::additions/removals()` 等返回数组副本；调用者修改这些数组不会修改库中的计划。快照包含独立的 sketch，后续改变 Inventory 不影响旧快照。

需要不保存完整 ID 的流式数据库接入时，可按唯一记录扫描构建 `Sketch`；底层 sketch 不跟踪去重，重复插入、无效删除都可能形成无法恢复的差异。高层 `Snapshot::from_sorted_ids(cursor, config, scope=..., epoch=..., max_members=...)` 支持直接扫描严格递增的 UInt64 游标，不建立完整 Map；重复或逆序 ID 会被拒绝，成员数超限会终止构建。除源游标外只需 O(width) 摘要内存。业务应保持扫描期间的数据库快照一致性。

## 普通同步

配置由双方协商，不接受对端随意指定无限制容量。`Config::new(width, seed=...)` 的 width 范围为 1..262144，实际总单元数为 3*width。不同配置不能相减。

`Policy::new(max_width=..., max_differences=...)` 限制重试空间和单次 peeling 工作量。`DecodeLimits` 限制收到帧的宽度和成员数，默认 width <=65536、成员数 <=10000000。可依据可用内存进一步下调。这里限制帧内存和工作量，不替代传输层读取超时或并发连接预算。

`reconcile(source_snapshot, target_snapshot, policy)` 的结果：

| 结果 | 应用动作 |
|---|---|
| `Ready(plan)` | 获取 additions 对应对象并认证内容；确认 source 仍是原快照；在业务事务中应用计划 |
| `Retry(config)` | 双方对原冻结快照重新生成同配置摘要，重试；不能只改变一端摘要 |
| `FullTransfer(residual)` | 应用选择全量交换、分区或推迟同步；库没有自动下载行为 |
| 抛出异常 | 拒绝这次请求，按类型排查 scope/config/版本/格式/限额；不要当成没有差异 |

`synchronize` 是两份本地 Inventory 的便利函数，用于测试或同进程同步；它不能代替网络协议。

`Inventory::apply` 先核对 scope、source_epoch 和源指纹，再对副本增删并核对目标指纹。它不执行磁盘提交、不持有业务锁、不授权删除对象。调用者应将此计划与业务系统的版本条件更新或事务组合。

epoch 是不透明的每节点版本，不用于选主或决定新旧。相同 ID 集合可有不同 epoch。若本地数据已变更，旧 plan 将被拒绝。业务需要禁止远端较旧版本覆盖时，应在调用前检查自己的版本规则。

## 分块接收

`FrameReader::feed(chunk)` 未收齐帧返回 None，完整且验证通过返回 Some(snapshot)。协议外的 EOF 调用 `finish()`，截断会报错。完整帧之后继续 feed 会报错；必须 `reset()` 后才能处理下一帧。错误后 reader 被标记失效并清空缓冲区，不会继续拼接残留字节。

reader 每次仅接收一帧，不能把多帧粘连数据一次送入 feed。应用的上层消息边界需拆分帧。对极小碎片会有逐字节处理成本，建议网络层使用正常大小缓冲区。

## 分区协商

1. 用同一个 `Layout` 对双方集合分区，固定 scope 和 epoch，构建 Manifest。
2. 将 Manifest 编码传输，接收方通过 `Manifest::decode` 验证帧与总体指纹一致性。
3. `Collector::new(source_manifest, target_manifest, max_changes=...)` 给出 `pending()` 编号。
4. 根据这些编号用 `bucket_offers` 批量生成摘要，或按编号 `bucket_offer`。前者一次扫描，但需限制全部摘要的总单元数。
5. 传输分区快照；分区编号和 Layout 由应用消息携带，用 `BucketOffer::new` 绑定快照。
6. `Collector::accept` 核查清单的 scope、epoch、指纹及恢复 ID 的分区归属。Retry 时只重新生成这个分区摘要。
7. 每个变化分区都 Ready 后才允许 `finish()`；它验证全部差异后的总体指纹，返回一个全局 Plan。

相同的已完成分区重传是幂等的；不完整分区不会进入已接受计划。单次 accept 的策略限制与 Collector 的整体 max_changes 是独立预算。Collector 只保存摘要与计划，不提供线程安全、网络传输或超时清理。

## API 分类

完整签名见根目录 `pkg.generated.mbti`，由 `moon info` 生成。

| 类型/函数 | 职责 |
|---|---|
| Config / Sketch / DecodeReport | 底层 IBLT 算法与有界恢复 |
| Fingerprint / Inventory / Snapshot | 本地集合、版本与冻结摘要 |
| Policy / reconcile / synchronize / Plan / Outcome | 有方向的同步计划和回退策略 |
| DecodeLimits / FrameReader | 不可信网络字节的有界接收 |
| Layout / Manifest / BucketOffer / Collector | 分区定位与完整计划合并 |
| ReconcileError | 配置、兼容性、格式、限额、失效及校验错误 |
