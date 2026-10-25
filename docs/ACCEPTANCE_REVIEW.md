# MoonReconcile 验收自查与交付进度

日期：2026-10-25。项目：十月黑客松已通过初审的 MoonReconcile。本文是开发者本地自查，不是组委会验收结果，不承诺奖金。十月的具体截止时间、验收入口与奖金安排以十月通知为准，不套用八月日程。

## 本次交付

| 已通过申报中的承诺 | 对应交付与证据 |
|---|---|
| 核心契约及边界 | [CORE_CONTRACT](CORE_CONTRACT.md)，独立 Sketch API；部分恢复不输出 Plan，核验失败使会话失效 |
| 累计预算控制 | exchange.mbt，字节/轮次/peeling 上限、精确重传、双方冻结身份、明确停止原因 |
| 双端接入示例 | examples/exchange，真实 MRCL 帧往返，首次/扩容/预算停止均带断言 |
| 恢复率与成本评估 | [EVALUATION](EVALUATION.md)，4500个核心样本、160次会话、240项minisketch对照及原始数据 |
| 独立发布接入 | tools/verify-consumer.mjs，使用固定版本注册表依赖；正式发布与冷安装待本次发布核验完成后记录 |

保留原[项目申报书](PROJECT_PROPOSAL.md)，不在初审后悄悄改写承诺。原2026-10-20设计保留历史状态，当前实现以本表及生成API为准。

## 验证证据

- 本地隔离安装官方 MoonBit 0.1.20261023 / moonc 0.10.17；未替换系统原工具链。修正新格式要求的 Int32 和可选参数写法，更新生成接口。
- wasm-gc、wasm、JS各60项测试通过，检查启用 deny-warn；格式和接口已重新生成。Native 构建/测试由Ubuntu CI验证，本机没有C编译器。
- GitHub [首次新增功能检查](https://github.com/apoloe4/moonreconcile/actions/runs/40157127139)：四目标功能测试成功，style因旧格式失败；已在后续提交修复格式。[运行40196667304](https://github.com/apoloe4/moonreconcile/actions/runs/40196667304)的四目标check/build/test/示例及style全部通过；[复跑评估40196667378](https://github.com/apoloe4/moonreconcile/actions/runs/40196667378)亦成功。
- [完整评估运行](https://github.com/apoloe4/moonreconcile/actions/runs/40157127172)成功；报告与CSV已归档。失败样本保留，无虚构结果或只挑选成功输入。
- 根目录Apache-2.0；[NOTICE](../NOTICE.md)说明IBLT、混合、CRC、AI辅助和minisketch对照的来源。运行时没有第三方C/C++实现；对照程序仅在CI临时目录链接上游MIT库。
- [最新生态查重](DUPLICATION_REVIEW.md)保留查询结果、候选版本与边界，不把无命中当成完全不存在。

## 未覆盖与限制

尚无第三方实际部署、真实数据库负载、认证网络或安全审计。minisketch对照只覆盖共同的小规模矩阵，不代表已测完全部大规模输入；双方全量构建成本未公平对照，因此不作速度领先宣称。CRC和集合指纹不是恶意输入认证。项目完成度与生产成熟度应分开评价。

## 参赛者验收提交

提交仓库主页 https://github.com/apoloe4/moonreconcile，附本报告、申报书、版本记录、CI及评估链接，按十月官方入口申请验收。初审通过通知未提供的具体截止时间和收款流程，需查阅官方后续通知。开发者应能解释核心算法、失败边界、测试与来源；AI辅助不能替代本人理解和维护。
