# 源码结构与维护入口

核心库集中在根包 `apoloe4/moonreconcile`。没有必须启动的服务，也没有JS/C包装层；Node与C++程序仅服务开发验证与离线对照。

| 文件/目录 | 职责 | 对应测试 |
|---|---|---|
| model.mbt、hash.mbt、sketch.mbt | 配置、指纹、分带哈希与IBLT恢复 | core_wbtest、extended_wbtest |
| inventory.mbt、session.mbt | 幂等集合、快照、单次差异核验和计划应用 | core_wbtest、moonreconcile_test |
| exchange.mbt | 跨轮预算、冻结身份、精确重传与停止状态 | exchange_wbtest |
| codec.mbt、stream.mbt | MRCL快照及单帧分块接收 | wire_wbtest |
| partition.mbt、manifest_codec.mbt | 分区清单、桶协商和全局计划核验 | partition_wbtest |
| capacity.mbt、streaming_snapshot.mbt | 单帧容量启发式、有序游标构建 | capacity_wbtest、streaming_snapshot_wbtest |
| examples/ | 基础、分区、容量、双端交换及评估程序 | CI运行样例及其断言 |
| tools/ | 编译器版本门槛、独立消费验证、统计报告、离线minisketch驱动 | CI执行 |
| docs/ | 接口契约、线格式、接入、查重、评估和验收证据 | 参见ACCEPTANCE_REVIEW |
| .github/workflows/ | 四目标check/build/test、格式、独立安装及完整评估 | GitHub Actions |

`pkg.generated.mbti`由`moon info`生成，不应手工维护；提交生成接口后CI检查无漂移。`_build/`、`target/`、`.mooncakes/`已忽略，不进入源码提交。

推荐阅读顺序：QUICKSTART → CORE_CONTRACT → SESSION → WIRE_FORMAT；修改核心逻辑后运行测试，再检查生成接口差异。保持PROJECT_PROPOSAL为已通过初审的历史申报材料，新进度写入CHANGELOG与ACCEPTANCE_REVIEW。
