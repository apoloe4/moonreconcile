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
