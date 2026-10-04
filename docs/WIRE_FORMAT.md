# 二进制格式 v1

所有多字节整数为 little-endian；UInt64 运算按 2^64 回绕。帧不压缩。CRC-32 使用反射多项式 0xedb88320，初值/终值异或 0xffffffff，覆盖除末尾 CRC 字段以外的全部字节。标准 `123456789` 向量为 0xcbf43926。

格式由本项目定义，尚无外部互操作实现，不是现有标准协议。数据保密与认证应由传输层提供。

## MRCL 快照帧

| 偏移 | 长度 | 字段 |
|---|---|---|
| 0 | 4 | ASCII `MRCL` |
| 4 | 1 | 版本，必须为 1 |
| 5 | 3 | 保留，全部为 0 |
| 8 | 4 | width，三个分带各有 width 个单元 |
| 12 | 4 | 精确集合成员数，不能超过接收限额或 Int 正范围 |
| 16 | 8 | 哈希 seed |
| 24 | 8 | dataset scope |
| 32 | 8 | snapshot epoch |
| 40 | 8 | 集合指纹 sum |
| 48 | 8 | 集合指纹 xor |
| 56 | 8 | 保留，必须为 0 |
| 64 | 60*width | 3*width 个单元，每个 20 字节 |
| 64+60*width | 4 | CRC-32 |

单元依次保存 count:u32、key_xor:u64、check_xor:u64。线上帧只保存原集合摘要，因此 count 非负；负计数只在内存中相减后的差异表中出现，不允许将它作为 Snapshot 传输。

帧总长度必须严格等于 `68 + 60*width`，禁止尾随字节。每个单元 count <=成员数；每个分带 count 之和=成员数；分带 key_xor 和 check_xor 总体相同。空单元必须全零，单成员单元的校验和哈希位置必须匹配。这些是结构校验，不能认证一个恶意节点的实际库存。

## MRPM 分区清单帧

64 字节头部与 MRCL 字段布局类似，magic 为 `MRPM`，偏移8为分区数量，偏移16为 Layout 路由 seed。偏移12为总成员数，40/48为总集合指纹。

之后每个分区24字节：count:u32、reserved:u32（0）、sum:u64、xor:u64，按分区编号递增。末尾 CRC-32。总长度 `68 + 24*buckets`。允许 1..4096 分区，接收端可设置更低上限；分区总指纹必须与头部总体指纹吻合。

分区快照仍使用 MRCL；scope 和 epoch 保留原数据集语义。外层应用消息需同时传分区编号及布局信息，接收方将其包装成 BucketOffer 并按已验证清单核查。库不定义网络信封格式。

## 混合与路由

使用 SplitMix64 finalizer：先 xor 右移30，乘 0xbf58476d1ce4e5b9；再 xor 右移27，乘 0x94d049bb133111eb；最后 xor 右移31。

分带索引分别为 `mix(id XOR seed XOR salt) % width + band*width`，salt 为 0x9e3779b97f4a7c15、0x3c6ef372fe94f82a、0xdaa66d2c7ddef743。校验值为 `mix(id XOR seed XOR 0xd6e8feb86659fd93)`。

集合指纹 count 为集合数量，sum 为每个 `mix(id XOR 0xa0761d6478bd642f)` 的模2^64和，xor 为每个 `mix(id XOR 0xe7037ed1a0b428db)` 的异或。分区编号为 `mix(id XOR layout.seed) % buckets`。

这些函数为确定性的非密码学混合，不声称独立随机性或不可伪造性。不同进程应使用一致版本、布局和配置。
