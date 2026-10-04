# 来源说明

本项目是依据公开算法说明独立编写的 MoonBit 实现，不是某个现有库的逐行移植。开发使用 AI 辅助生成、检查代码与文档；参赛者应阅读、运行测试并理解实现，不能把 AI 辅助草稿表述为未经辅助的个人原创算法。

| 来源 | 参考范围 | 代码复用情况 |
|---|---|---|
| [Goodrich 与 Mitzenmacher：Invertible Bloom Lookup Tables](https://arxiv.org/abs/1101.2245) | 计数、异或、校验与 peeling 算法思想 | 没有复制论文文本、图表或论文配套代码 |
| [SplitMix64 作者参考实现](https://prng.di.unimi.it/splitmix64.c) | 64 位混合函数的数学变换和常数 | 该参考实现注明 public domain；本项目以 MoonBit 实现 finalizer，不声称提供完整随机数生成器 |
| [RFC 1952](https://www.rfc-editor.org/rfc/rfc1952) | IEEE CRC-32 多项式与位运算算法 | 未复制 RFC 样例代码；自行实现循环并用标准向量验证 |
| [bitcoin-core/minisketch](https://github.com/bitcoin-core/minisketch) | 查重与同类生态价值对照，采用不同的 BCH 算法 | 没有复用代码，亦不兼容其格式 |
| [hoytech/negentropy](https://github.com/hoytech/negentropy) | 查重与范围协商方案对照 | 没有复用代码，亦不兼容其协议 |

`docs/research` 中的文本是 Mooncakes 搜索命令输出，用于记录检索事实，不作为本项目算法或代码。测试数据是自行构造的整数集合、确定性生成的字节以及公开标准 CRC 测试字符串。没有加入竞品源码或第三方二进制。

本项目代码适用 Apache-2.0，见根目录 LICENSE。算法名称和外部项目商标归相应权利人所有。
