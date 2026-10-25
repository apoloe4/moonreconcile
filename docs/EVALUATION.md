# 恢复率与成本评估

## 复现

```sh
moon run examples/evaluate --target js --release > core.csv
moon run examples/evaluate --target js --release -- --sessions > sessions.csv
node tools/summarize-evaluation.mjs core.csv sessions.csv > REPORT.md
```

快速矩阵：n=1000/10000，d=0/2/20/200，width=max(1,d×0.5/1/2)，种子1..10，共240行。完整矩阵增加 n=100000、d=2000，并使用种子1..100，共4500行：

```sh
moon run examples/evaluate --target native --release -- --full > core.csv
```

native 需要本机 C 编译器。公开 [evaluation 工作流](../.github/workflows/evaluation.yml)在 Ubuntu 自动运行完整矩阵、160次会话协商与锁定版本 minisketch 的240项对照，上传原始 CSV、工具链版本及报告。脚本、种子和失败行全部保留。n 是每一端的成员数；平衡差集各端独有 d/2 个，所有输入是确定生成的非零64位ID，不是真实数据库样本。

## 已执行的结果

2026-10-25，[运行40157127172](https://github.com/apoloe4/moonreconcile/actions/runs/40157127172)通过。MoonBit 0.10.17、Linux native；原始结果归档在 [evaluation/2026-10-25](evaluation/2026-10-25/)。该报告绑定代码 b6d4df1，后续格式迁移不修改算法。4500行中也包含失败：d=2、width=2时265/300成功；width=4时297/300成功。d=20、width=10时187/300成功。这说明不能用 width≥d 推出必然成功。

跨轮次协商的预算为512和65536字节，各80组：前者20组成功，后者80组成功。成功会话计入实际双向帧与重试后为256..31688字节。大预算未在此有限样本中失败，不代表生产成功率100%；高差异率时也可能超过全量清单成本。

minisketch 对照为同样的240组共同输入，容量内180组均通过精确差集核验。对照驱动预先消去共同元素，只测差集解码与裸摘要大小，**没有测其全量集合构建成本**。本库 CSV 的 decode_us 包含相减，两个计时边界并非完全相同；报告不根据这些单次时间宣称速度优势。比较时区分 minisketch 裸摘要与含元数据的 MRCL 帧。

## 方法边界

- build_us 为双方完整表的构建时间；decode_us 为相减、私有副本 peeling 和排序。精确正确性断言在计时外。
- frame_bytes 只是一帧，不是会话成本；会话 CSV 才累计 sent_bytes/received_bytes。后续全量回退、对象内容、网络头另算。
- 每条完整恢复均与精确差集对照；恢复失败保留 residual 和 steps，不发布应用计划。
- 输入种子改变 ID 与哈希配置。不同 n 的样本可能相关；汇总比例是该固定矩阵的经验值，不是独立抽样置信区间或最坏情况界限。
- 微秒为单次观察，包含运行时和计时噪声，无稳定计时或显著性检验。此前的 [BENCHMARK](BENCHMARK.md) 是另一组阶段微基准，不等于这里的恢复率评估。
- 矩阵没有真实数据库 IO、网络延迟、恶意节点或长期负载；单边差异和高差异率正确性另由测试覆盖，不能将本矩阵等同全部工作负载。

仅当同一具体业务上的摘要、重试和处理成本确实优于完整清单时才值得采用；小集合、高差异率、极低带宽之外的不同约束可能使完整清单或其他算法更合适。
