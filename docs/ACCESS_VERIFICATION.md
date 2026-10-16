# 公开访问与克隆核验

核验日期：2026-10-16。核验的代码提交为 `4e03259bcedddc21e4b1c633219283b4efddb11b`，默认分支 `main`，当时包含11次提交。本记录及链接说明属于后续文档修正。

## 报名应填写的地址

仓库主页：

```text
https://github.com/apoloe4/moonreconcile
```

HTTPS 克隆地址：

```text
https://github.com/apoloe4/moonreconcile.git
```

申报书：[docs/PROJECT_PROPOSAL.md](PROJECT_PROPOSAL.md)。

`https://github.com/apoloe4/moonreconcile/commits/main` 是提交记录页，可以浏览提交历史，但不是 Git 仓库入口；它只能用于单独要求填写提交历史的字段，不能填入仓库地址栏。报名表应粘贴上面仓库主页的纯 URL，不要包含 Markdown 的方括号和圆括号。

## 实测结果

| 检查 | 结果 |
|---|---|
| GitHub 仓库元数据 | PUBLIC，isPrivate=false，isArchived=false |
| 不携带登录信息访问仓库主页 | HTTP 200 |
| 不携带登录信息访问申报书 | HTTP 200 |
| 不携带登录信息访问 README 原文 | HTTP 200 |
| 正确 HTTPS 地址匿名查询 HEAD/main | 成功，指向上述代码提交 |
| 正确 HTTPS 地址完整匿名 clone 到新目录 | 成功，包含源码、文档与11次提交 |
| 在新克隆目录执行 `moon check --deny-warn` | 通过 |
| 在新克隆目录执行 `moon test --deny-warn` | 48项全部通过 |
| 将 `/commits/main` 页面用作 Git 地址 | 失败，`info/refs not valid: is this a git repository?` |

Git 操作设置 `GIT_TERMINAL_PROMPT=0`，并使用 `-c credential.helper= -c core.askPass= -c http.extraHeader=`，不依赖登录凭据或授权头。网页检查使用不含授权头或 Cookie 的 curl 请求。

本次网络请求经本机代理连接 GitHub。代理只用于本机网络连通，不提供仓库访问权限。成功核验表明仓库本身无需登录即可获取，不代表任意地区、任意时刻均不会遇到网络故障，也无法还原评审当时的环境。

## 复现

```sh
git -c credential.helper= -c core.askPass= -c http.extraHeader= clone https://github.com/apoloe4/moonreconcile.git
cd moonreconcile
moon check --deny-warn
moon test --deny-warn
```

如遇连接超时，请检查到 github.com 的网络；如遇 `not a git repository`，先检查是否误用了 `/commits`、`/blob` 或 `/tree` 等网页路径。申报材料的仓库主页和 Git 克隆地址分别使用上面给出的两个规范地址。
