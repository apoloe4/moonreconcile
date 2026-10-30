# 十月验收指南逐项对照

更新：2026-10-30。依据参赛者提供的九项验收指南，初审通过者**无需另填验收表格**，持续开发并将对应内容上传GitHub即可。此前文档关于“需要申请验收入口/再交表”的说明已撤回。本文是工程自查，官方验收和奖金仍由组委会决定。

## 九项要求与证据

| 项 | 指南要求 | 项目对应实现与核验方式 |
|---|---|---|
| 1 | MoonBit为主，moonc≥0.10.16 | 算法、帧编解码、分区和会话均为MoonBit；项目采用已验证的moonc **0.10.17**基线，高于赛事下限。CI执行 `node tools/check-toolchain.mjs` 检查实际编译器，拒绝过旧/无法识别的版本 |
| 2 | GitHub公开、记录清晰 | [公开主页](https://github.com/apoloe4/moonreconcile)，默认分支main；提交分别覆盖算法、测试、评估、兼容修复和发布，不用空提交凑数 |
| 3 | 结构清晰、核心功能有效 | [源码职责](PACKAGE_LAYOUT.md)、[核心契约](CORE_CONTRACT.md)、[会话接入](SESSION.md)；实现差异ID恢复、计划核验、预算停止、快照失效及精确重传 |
| 4 | README有目标、安装、使用与示例，可复现 | [README](../README.md)、[从空目录安装](QUICKSTART.md)；给出moon.mod、moon.pkg、main.mbt、安装/检查/构建/运行及预期输出 |
| 5 | CI覆盖检查、构建、测试 | [ci.yml](../.github/workflows/ci.yml)在wasm-gc/wasm/js/native执行check/build/test，另查格式、生成接口和独立注册表消费 |
| 6 | 至少一个可运行样例 | `moon run examples/basic`；`moon run examples/exchange`验证首次成功、扩容、预算回退，结果用断言核验 |
| 7 | 测试覆盖核心路径 | 60项自动测试，包含120组生成式会话、精确差集对照、损坏帧、溢出、预算边界、重传和失效；详见 [TESTING](TESTING.md) |
| 8 | 发布mooncakes.io | [apoloe4/moonreconcile@0.2.1](https://mooncakes.io/docs/apoloe4/moonreconcile@0.2.1)，固定版本安装；独立消费者不使用本地path依赖，执行update/check/build/run |
| 9 | OSI许可证及上游合规 | 根目录[Apache-2.0](../LICENSE)；[NOTICE](../NOTICE.md)记录算法参考、CRC、混合函数、AI辅助及minisketch的MIT来源；对照库不进入运行依赖 |

## 声明功能的交付证据

原[已通过初审申报书](PROJECT_PROPOSAL.md)保持不变。核心契约、跨轮预算控制和双端示例已交付；原始4500个核心样本、160次会话与240项minisketch对照在 [EVALUATION](EVALUATION.md)，失败行同样归档。当前补丁不改变算法和MRCL/MRPM格式，版本差异见 [CHANGELOG](../CHANGELOG.md)。

本地使用隔离的官方MoonBit 0.1.20261023 / moonc0.10.17运行check、build、test、fmt和info；60项测试通过。实际版本门槛验证：系统旧moonc0.10.14被拒绝，隔离moonc0.10.17通过。没有改写系统工具链。Native由Ubuntu CI验证，本机没有C编译器。

0.2.0的[已通过CI](https://github.com/apoloe4/moonreconcile/actions/runs/40197308436)覆盖四目标、格式与独立消费；[完整评估](https://github.com/apoloe4/moonreconcile/actions/runs/40197308465)亦通过。0.2.1的[运行41003897135](https://github.com/apoloe4/moonreconcile/actions/runs/41003897135)已通过四目标check/build/test/示例、工具链门槛、格式、生成接口及全新独立模块安装检查。正式发布返回200 OK；注册表下载0.2.1后独立执行update/check/build/run（JS与默认WebAssembly运行均验证），输出 `published 0.2.1: exact target verified`。

## 规模、来源与实际边界

根包排除注释与空行约1358行运行时代码、902行测试；不把CSV、文档、C++对照驱动计入MoonBit实现量。主要实现语言与有效功能应以源码和运行结果判断，不靠数据文件充行数。

IBLT不是原创算法；[查重复核](DUPLICATION_REVIEW.md)只是在公开查询与六个相邻包版本范围内的比较，不宣称全生态唯一。minisketch仅在离线CI临时目录编译链接，其MIT实现未复制进运行库。

尚无真实数据库长期负载、认证网络或第三方安全审计。概率指纹和CRC不是身份认证；传输、内容验证、持久化、冲突解决和全量回退由应用负责。对照评估有清晰的计时/样本边界，不宣称速度优势或必然恢复。

## 后续维护

无需为本次验收再提交表格。保持main分支可访问，持续上传真实开发、测试和文档；参赛者应理解算法、失败边界及来源，并关注组委会后续通知。奖金与最终验收结果不由本报告保证。
