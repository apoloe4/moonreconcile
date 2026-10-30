# 从空目录安装并运行

要求：官方 MoonBit 工具链，`moonc -v` 不低于 **0.10.17**（本项目已验证的基线，也满足赛事要求的0.10.16下限）。默认使用 wasm-gc，无需 C 编译器或服务器。Node.js 22+ 仅用于JS目标与仓库开发验证脚本，不是库的外部运行时依赖。

## 1. 创建模块

新建空目录 `reconcile-demo`，进入该目录，创建 `moon.mod`：

```toml
name = "demo/reconcile"
```

在该目录执行：

```sh
moon add apoloe4/moonreconcile@0.2.1
```

创建 `moon.pkg`：

```moonbit
pkgtype(kind: "executable")
import { "apoloe4/moonreconcile" @reconcile }
```

## 2. 创建最小样例

创建 `main.mbt`，内容如下。这也是独立消费者CI实际运行的样例：

```moonbit
fn main {
  try {
    let source = @reconcile.Inventory::from_ids([0UL, 1UL, 2UL], scope=7UL, epoch=3UL)
    let target = @reconcile.Inventory::from_ids([0UL, 2UL, 3UL], scope=7UL, epoch=5UL)
    let config = @reconcile.Config::new(16)
    let frozen = source.snapshot(config)
    let session = @reconcile.Session::new(frozen, target.epoch(), @reconcile.SessionLimits::new())
    session.record_sent(frozen.encode()) |> ignore
    match session.receive(frozen, target.snapshot(config).encode()) {
      Complete(plan) => assert_eq(source.apply(plan).ids(), target.ids())
      _ => fail("published library did not recover exact target")
    }
    println("published 0.2.1: exact target verified")
  } catch { e => abort(e.to_string()) }
}
```

## 3. 检查、构建、运行

```sh
moon check --deny-warn
moon build --deny-warn
moon run .
```

预期输出：`published 0.2.1: exact target verified`。断言确保最终ID精确等于目标集合，而不只是能启动进程。若使用JS目标，执行 `moon run . --target js`，需要Node.js。

## 仓库内一键复现独立消费者

已经克隆本仓库且有Node.js 22+时，可以在仓库根目录执行：

```sh
node tools/check-toolchain.mjs
node tools/verify-consumer.mjs ../moonreconcile-consumer
```

目标目录必须不存在，避免覆盖个人文件。脚本创建上面的三个文件，从注册表获取moon.mod中声明的发行版本，执行update/check/build/run。它不使用本地path依赖。可选第三参数指定历史版本，如 `0.2.0`。CI使用全新临时目录验证同一路径。

克隆源码后无需网络即可运行库本身的基本示例（前提是已安装工具链和标准库）：`moon run examples/basic`；双端交换、重试和预算回退见 `moon run examples/exchange`。首次安装包、更新注册表及安装工具链需要网络。
