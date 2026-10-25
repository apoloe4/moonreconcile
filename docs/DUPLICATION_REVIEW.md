# MoonReconcile 生态查重复核（2026-10-25）

复核范围：公开 Mooncakes 包、GitHub 仓库和候选包已发布版本的 README/API/相关源码。结论是有限范围的功能重叠判断，不是源码相似度鉴定、著作权/专利审查或官方验收结论。

## 查询与证据

- `moon search <keyword> --limit 20`：iblt、ibf、minisketch、riblt、pinsketch、rateless、negentropy 均无模块命中。reconcile/reconciliation 多为账务、控制器状态与工作流协调；这些名称相似但问题域不同。
- sketch 共返回13个模块；增加 distinct、merkle 查询，以覆盖统计摘要及树式同步的相邻方向。部分通用查询到达20条上限，不代表穷尽结果。
- GitHub 查询 `iblt language:MoonBit` 仅命中本项目；`minisketch language:MoonBit`、`set-reconciliation language:MoonBit`、`invertible bloom MoonBit` 无命中。GitHub仓库搜索不等于全站源码搜索。
- 原始输出：[research](research/)，文件前缀 `2026-10-25-`，GitHub结果为JSON。Mooncakes某些详情页访问失败，改用独立研究模块下载源码；研究依赖未加入项目运行依赖。

## 候选与实际范围

| 候选/核查版本 | 核查依据与能力 | 差异与重叠 |
|---|---|---|
| hiroyannnn/sketch 0.2.0 | 已下载接口与README；HLL、Count-Min、Cuckoo | 同属概率结构，但统计/成员查询不恢复双方独有ID |
| cauchyQ/moon-sketch-kit 0.1.0 | 已下载接口；Bloom、MinHash、频次/流分析、预算报告 | 存在预算和摘要等工程概念重叠；未发现IBLT signed peeling |
| Hhsqoo/moon-frequency-sketch 0.2.0 | codec接口中的sketch_diff输入含外部候选字符串列表，返回频次变化 | 已有摘要差异功能，不能说“只有本项目能比较摘要”；它依赖给定候选键，不是从集合摘要恢复未知差异ID |
| zploc/loci 0.1.0 | [包文档](https://mooncakes.io/docs/zploc/loci)与本地tree接口；diff_trees/diff_sparse_trees | 已有Merkle差异定位，与集合核对相邻；本项目采用IBLT恢复，不主张同步需求独占 |
| yhsrtty/moon-distinct-sketch 0.2.1 | 本次新增下载；README、metrics及serde/distributed接口 | 基数、频次、相似度、快照差值、帧和重放控制；这些工程能力不算本项目原创，未发现未知差异ID恢复接口 |
| Juwan-Hwang/moon-certified 0.1.1 | 本次新增下载；containers/count_sketch、count_min_sketch、hyperloglog等接口及相关标识全文检索 | 已有基础算法与统计摘要，未发现IBLT/PinSketch/Rateless集合恢复接口；invertible字样的数学可逆性命中不等于IBLT |

其余sketch命中包括CAD草图、图像效果、证明示例、路径规划和科学计算模块；本次做描述分流，未声称逐个完整审计。相邻六包的检查也不是对每一个函数的全面安全审计。

## 独立贡献与边界

保留已通过初审的同一选题和仓库，新增工作是纯MoonBit可复用的集合差异恢复、受预算约束的会话状态机、固定快照与精确重传，以及可复现失败数据。协议帧、CRC、版本检查、预算和测试属于常见工程做法，不单独宣称算法创新。IBLT本身是已有算法，出处见NOTICE。

成熟的[bitcoin-core/minisketch](https://github.com/bitcoin-core/minisketch)同样解决集合差异恢复，已实际编译用于240项对照。不能因它不是MoonBit包就忽略其设计与成本优势；本项目不复制其实现，不宣称比其更紧凑或更快，不兼容其格式。保留IBLT是否适合实际业务，需要根据[EVALUATION](EVALUATION.md)的失败率和成本决定。

## 复核结论

在以上查询与明确版本的核查范围内，未发现另一项直接对应的MoonBit IBLT差异ID恢复库；存在统计摘要、快照差值、Merkle树差异等相邻成熟能力。该判断支持解释实现差异，不等同于“全生态唯一”或“必然通过验收”。未发布项目、检索遗漏、后续新增包及同赛道未公开申报仍无法排除。初审已通过也不替代最终质量验收。

---

## 历史记录（2026-10-04）

以下为首次选题时的记录，状态与结论只属于当时；当前实现和查重以本页上半部分为准。

# MoonReconcile 选题查重记录

检索时间：2026-10-04。目标是判断公开 MoonBit 生态是否已有直接功能重叠，并解释独立库价值，不是官方审核结论，也不是完整的著作权或专利检索。

## 检索方法

使用 `moon search <keyword> --limit 12`，关键词包括 `iblt`、`ibf`、`minisketch`、`reconcile`、`reconciliation`、`sketch`；原始输出保存在 [research](research/) 目录。补充检索 GitHub 与公开网页中的 `MoonBit IBLT`、`MoonBit invertible bloom`、`MoonBit set reconciliation`、`MoonBit 集合同步`。

`iblt`、`ibf`、`minisketch` 在本次 Mooncakes 查询均显示 `No modules found`。通用关键词有大量相邻和无关结果，不能把关键词无结果解释为生态绝对空白。`--limit 12` 是结果数量限制，不构成对全部包的穷尽扫描。

## 相关 MoonBit 项目与源码核查

为避免只看包名，从 Mooncakes 下载以下版本到工作区独立的研究目录，检查 README、公开 API 与 MoonBit 源码。研究目录不进入本项目依赖，也不复制源码。

| 现有项目及核查版本 | 已核查的功能 | 与本项目的区别 |
|---|---|---|
| [hiroyannnn/sketch 0.2.0](https://github.com/hiroyannnn/sketch) | HyperLogLog、Count-Min Sketch、Cuckoo Filter | 数量、频次和成员查询；本项目从双方摘要恢复有方向的差异 ID |
| [cauchyQ/moon-sketch-kit 0.1.0](https://github.com/cauchyQ/moon-sketch-kit) | 流式近似分析、Bloom、MinHash、Top-K 等 | 分析与统计工具；未发现 IBLT signed peeling 或集合差异恢复接口 |
| [Hhsqoo/moon-frequency-sketch 0.2.0](https://github.com/Hhsqoo/moon-frequency-sketch) | 频次、重频项、基数、分位数、过滤器及序列化 | 有摘要序列化但用途不同；未发现双方集合摘要相减后恢复差异 ID 的接口 |
| [zploc/loci 0.1.0](https://github.com/zpc-sh/loci) | Bloom 路由、Merkle 树、`diff_trees`/`diff_sparse_trees` | 已有差异同步相邻能力，不能称“生态没有同步”；本项目无需双方交换完整树结构，采用 IBLT 摘要及容量重试 |

源码全文检索 `iblt|invertible|reconcil|pin.?sketch|rateless` 未找到上述四个已下载版本的相关实现标识；同时检查了统计库接口与 loci 的树差异接口。命名检索本身不能证明不存在等价实现，因此结论结合接口与 README 范围，而不是只依赖无匹配结果。

Moocakes 部分详情页本次网页工具不可访问，相关核查改用工具链实际下载包的源码；没有将详情页访问失败当成包不存在。

## 其他语言的同类方案

IBLT 是已有研究算法，**不主张算法原创**。参考 [原始论文](https://arxiv.org/abs/1101.2245)。[minisketch](https://github.com/bitcoin-core/minisketch) 提供 BCH 集合摘要，[Negentropy](https://github.com/hoytech/negentropy) 提供范围式差异同步，说明此需求在其他生态已有独立可复用实现。MoonReconcile 没有复用这两个库的代码，不使用 C FFI，不声称协议兼容。

## 独立贡献与适用性

本项目提供 MoonBit 原生的差异恢复算法、可检验二进制格式、增量帧接收、容量重试、快照失效防护、分区清单协商和全局同步计划校验。可服务边缘缓存、备份清单、离线索引等不同应用。网络、实际内容传输、持久化和业务冲突由应用实现，库的边界是集合差异同步基础能力。

相较被驳回的 CSV 和改名项目，这个方向的新增贡献集中在可复用算法与同步基础库，而非通用工具的界面包装；这是一项基于范围比较的判断，不是通过率承诺。

## 结论与剩余风险

在本次公开检索及四个相邻包版本的源码范围内，未发现直接对应完整 IBLT 集合差异同步库。存在统计摘要、Merkle 树差异等相邻能力，因此应如实说明区别。

风险包括未发布/未被搜索引擎收录的项目、后来新增包、同一赛道其他参赛申报、概率算法的工程成熟度及实际复用需求。当前版本属于实验性完整实现，需要外部用户验证和性能评估；不保证初审、验收或获奖。申报前应再次运行检索，并由参赛者确认项目必要性。
