# MoonReconcile：MoonBit 集合差异同步库

两端都有大量记录、只有少数 ID 不同时，先交换紧凑摘要，再恢复双方缺少的 ID，减少全量清单传输。核心算法、协议处理、分区协商和测试均以 MoonBit 实现，无 JS 包装层、C FFI 或外部运行库依赖。

**当前状态：0.1.0 实验版本。** 面向合作节点的集合同步；不是数据库、文件同步软件或已通过生产审计的安全协议。摘要格式是本项目自定义格式，不兼容 minisketch、Negentropy 或其他 IBLT 实现。

## 可以解决什么问题

| 场景 | 输入 | 处理过程 | 输出 |
|---|---|---|---|
| 边缘缓存与中心索引同步 | 双方缓存对象的稳定 UInt64 ID | 交换快照摘要、恢复差异、拉取缺少对象 | 新增与移除 ID 清单 |
| 备份清单核对 | 本地与远端备份块 ID | 分区清单定位变化、只交换变化分区摘要 | 需要补传或复核的块 ID |
| 离线节点重新连接 | 双方事件/文档版本 ID | 固定快照版本、重试扩大摘要、校验结果 | 同步计划或全量回退建议 |

业务负责获取、验证和存储实际内容；本库同步的是 **ID 集合**。同一记录内容变化必须产生不同 ID，或由应用另行核对版本。

## 已实现

- 三个互不重叠的哈希分带，带有计数、ID 异或与 64 位校验摘要的 IBLT；支持插入、删除、相减及正负差异恢复。
- `Inventory` 提供精确本地去重、幂等变更、快照版本号和不可变同步计划；`apply` 返回新集合，失败不会修改源集合。
- `reconcile` 明确返回 `Ready / Retry / FullTransfer`；恢复不完整时不发布同步计划。
- MRCL 二进制快照、MRPM 分区清单、CRC-32、版本/保留字段检查、长度检查、分配上限及分带一致性检查。
- `FrameReader` 支持分块输入、截断检测和错误后重置。
- `Layout / Manifest / BucketOffer / Collector` 支持先定位变化分区、任意顺序收集、幂等重传及全局差异数量限制。
- 可运行的基础、分区和容量回退示例；确定性生成测试、异常输入测试与多编译目标 CI。

## 立即运行

安装 [MoonBit 工具链](https://www.moonbitlang.com/download)，进入仓库根目录：

```sh
moon check --deny-warn
moon test --deny-warn
moon run examples/basic
moon run examples/partitioned
moon run examples/capacity
```

基础示例输出新增 `[5]`、移除 `[1, 4]`，同步结果 `[2, 3, 5]`。不需要服务器、密钥、账号或网络。

本地使用本仓库的方式：把自己的示例包放入同一模块并在 `moon.pkg` 中导入：

```moonbit
import { "apoloe4/moonreconcile" @reconcile }
```

目前尚未发布到 Mooncakes，不能假定 `moon add apoloe4/moonreconcile` 已可用。发布后会在这里更新安装说明。

## 核心 API

以下语句放在可抛出异常的函数中，完整版本见 `examples/basic/main.mbt`：

```moonbit
let source = @reconcile.Inventory::from_ids([1UL, 2UL, 3UL], scope=42UL, epoch=7UL)
let target = @reconcile.Inventory::from_ids([2UL, 3UL, 4UL], scope=42UL, epoch=9UL)
let config = @reconcile.Config::new(16)
let wire = target.snapshot(config).encode()
let received = @reconcile.Snapshot::decode(wire, @reconcile.DecodeLimits::new())
match @reconcile.reconcile(source.snapshot(config), received, @reconcile.Policy::new()) {
  Ready(plan) => {
    let result = source.apply(plan)
    assert_eq(result.ids(), target.ids())
  }
  Retry(next) => { next.width() |> ignore }
  FullTransfer(_) => { /* 由应用执行全量 ID 清单交换 */ }
}
```

`scope` 必须标识同一个数据集；`epoch` 是各节点自己的版本标签，双方不需要相等。目标版本可以小于源版本，库不会自行判断哪个节点更权威。应用必须决定同步方向并验证授权。`Inventory` 幂等变更不会增加版本号，实际增删会增加。

## 网络接入流程

1. 冻结双方快照，协商同一个 scope、宽度和 seed。
2. 经应用的 HTTP/WebSocket/其他通道传输 `Snapshot::encode()` 数据。
3. 用 `DecodeLimits` 和 `Snapshot::decode`，或分块 `FrameReader` 接收。
4. `Ready` 后根据新增 ID 拉取并验证内容，再在业务事务中提交变更。
5. `Retry` 时双方针对同一冻结快照重新生成摘要；`FullTransfer` 时应用交换全量清单。

分区模式先交换 `Manifest::encode()`，再由 `Collector::pending()` 给出需交换摘要的分区编号；每个分区独立重试，最后 `finish()` 合并成一个经全局校验的计划。分区编号和布局作为应用消息元数据传输，用 `BucketOffer::new` 包装收到的快照。完整流程见 `examples/partitioned`。

## 容量与成本

`width` 为每个分带的单元数量，总单元数为 `3 * width`。快照线长为 `68 + 60 * width` 字节。容量应该随预计差异数量选择，并用实际负载测量成功率；不承诺某个差异数必然成功。容量不足时加倍宽度，达到策略上限后回退。

本地 `Inventory` 精确保存全部 ID，内存为 O(n)；摘要是 O(width)，构建 O(n)，恢复工作量受预算限制，结果排序 O(d log d)。分区清单 O(b)，批量分区摘要构建只扫描一次本地集合；按单个分区重复生成摘要会多次扫描集合。

固定示例：10,000 条 ID、2 个差异、64 分区，接收清单 1,604 字节，接收变化分区摘要 616 字节，合计 2,220 字节；全量 ID 数组为 80,000 字节。这里只比较该示例的接收数据，不包含请求、传输协议、发送端摘要或实际对象内容，不是普遍性能保证。

## 使用边界

- IBLT 恢复及指纹校验属于概率方法，存在碰撞或恢复失败的可能。恢复失败会明确返回，但不能宣称不存在指纹碰撞。
- 内部混合函数和 CRC-32 **不是密码学认证**。恶意对端、数据隐私和防重放由应用的认证通道、版本策略、内容哈希与授权处理。
- 不实现网络连接、数据库事务、持久化、定时任务、业务冲突解决、全量传输或对象下载。
- `Sketch::insert/erase` 是底层代数操作，调用者需保证合法集合增删；需要去重时使用 `Inventory`。
- 共享实例不提供线程同步；并发应用应冻结快照或在外部加锁。

## 文档和来源

- [查重记录](docs/DUPLICATION_REVIEW.md)：检索范围、竞争库源码核查与不确定项。
- [接口使用指南](docs/USAGE.md)、[二进制格式](docs/WIRE_FORMAT.md)、[测试说明](docs/TESTING.md)。
- [项目申报书初稿](docs/PROJECT_PROPOSAL.md)：供参赛者理解和自行润色。
- [来源与许可证说明](NOTICE.md)：算法参考论文、混合函数和 CRC 来源，AI 辅助说明。
- 根目录 [Apache-2.0 许可证](LICENSE)。
