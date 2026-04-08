# WADJET 漏洞验证报告（作业）

## 1. 研究目标

本实验目标是验证以下问题：

1. 合约是否存在可被持续利用的套利路径。
2. 攻击者在多轮复投与提现下，是否能够持续抽取资金。
3. 在当前测试参数下，首次失败（revert）大约发生在第几轮。
4. 攻击者最终可提取多少，是否达到相对初始资产的净盈利。

---

## 2. 相关业务逻辑

核心函数位于 [src/WADJET.sol](src/WADJET.sol)：

1. `reinvest()`
	- 通过位图记录 21 天周期中的复投打卡状态。
	- 当满足可提现条件且 `rateSet == false` 时会提高 `rate`（`+15`）。
2. `canWithdraw(address)`
	- 需要在当前 21 天周期内完成 day0 到 day19 的连续复投，且当天是 day20。
3. `withdraw()`
	- 先向多个地址分发费用，再向用户转账净收益。
	- 用户累计提现受上限限制（不超过 `8 * investment`）。
	- 余额不足时会在转账阶段回滚。
4. `reset(address)`
	- 重置周期状态并将 `rate` 恢复到 5。

---

## 3. 利用链思路

攻击链在测试中被建模为：

1. 攻击者 Alice 先大额入金（10 ETH），建立较大的收益基数。
2. 多个下级账户（user1~user9）以 Alice 为推荐人入金，抬高池子总余额并给 Alice 带来推荐相关收益累积。
3. Alice 在每个周期执行 day0 到 day19 连续复投，day20 发起提现。
4. 周期重复后，池子余额逐步下降；当池子不足以支付当前轮提现及费用时，`withdraw()` 回滚。

该链路验证了“可持续抽池直到失败点”的行为，而不是单次瞬时盗取。

---

## 4. 测试实现

测试文件为 [test/attackTest.t.sol](test/attackTest.t.sol)，主要包含：

1. `test_attack()`
	- 验证前两轮攻击过程和资金变化。
	- 在后续循环中继续执行多轮复投/提现，并记录首次回滚轮次。
2. `test_attack_multiRounds_untilRevert()`
	- 独立压力测试，循环执行“day0~day19 复投 + day20 提现”。
	- 用低级调用捕获 `withdraw()` 失败点，避免测试整体被一次回滚提前中断。
	- 输出累计提现、净流入、池子剩余余额等量化指标。

注意事项（测试中已修复）：

1. 每轮必须包含 day0 复投，否则位图条件不满足。
2. 周期起点必须单调递增，避免时间倒退导致断言/下溢问题。
3. 对潜在失败的提现调用应使用可捕获返回值的方式统计首个失败轮次。

---

## 5. 实验结果（当前参数）

在参数 `Alice=10 ETH`、`9 个用户各 0.2 ETH` 下，压力测试得到：

1. 首次提现回滚轮次：171
2. 成功提现轮次：170
3. Alice 累计提现：`7943575291276023548 wei`（约 7.9436 ETH）
4. Alice 相对初始余额净套利：0（尚未回本）
5. Alice 在扣除自身入金后的净流入：约 7.9436 ETH
6. 池子最终余额：`45079034819264283 wei`（约 0.045 ETH）

---

## 6. 结论

1. 合约存在可被多轮策略持续利用的抽池路径。
2. 在当前实验参数下，攻击可以持续到第 171 轮附近出现首次提现失败（池子资金不足）。
3. 该参数组合下，攻击者虽能大量提取，但未达到相对初始资产的净正收益（仍未完全回本）。
4. 因此可判定：
	- 漏洞利用链成立（可持续消耗池子流动性）。
	- 盈利与否依赖初始入金结构、池子规模与参与者资金分布。

---

## 7. 复现实验命令

在项目根目录执行：

```bash
forge test --match-test test_attack -vv
forge test --match-test test_attack_multiRounds_untilRevert -vv
```

运行结果:
```bash
[PASS] test_attack() (gas: 72671261)
Logs:
  Alice reinvest for:  1048575
  Balance of Alice before is:  10000000000000000000
  Balance of Pool before is:  10325000000000000000
  Balance of Alice is:  10047142867650664254
  Pool's balance is:  10263991583040316852
  second Alice balance is:  10093867307481943913
  second Pool balance is:  10203524660905719650
  After more rounds: 
  Balance of Alice final:  17943573199136926625
  Balance of Pool final:  45081742293389714
  loop rounds:  169

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 264.54ms (262.65ms CPU time)

Ran 1 test suite in 265.38ms (264.54ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

