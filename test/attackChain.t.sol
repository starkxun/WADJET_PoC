pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WADJET} from "../src/WADJET.sol";


// 示例骨架
contract attackForkTest is Test {
    WADJET internal wadjet;
    address constant TARGET = 0x4ef1dcfdcf8f4b99deba2567c4110b06b649ae0f;

    address internal Alice;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("bsc")); 
        // 为了结果可复现，建议加 block number:
        // vm.createSelectFork(vm.rpcUrl("bsc"), 48000000);

        wadjet = WADJET(payable(TARGET));

        Alice = makeAddr("Alice");
        vm.deal(Alice, 20 ether);
    }

    function test_attack_on_bsc_fork() public {
        address ref = wadjet.devAddress();

        vm.prank(Alice);
        wadjet.deposit{value: 10 ether}(ref);

        vm.prank(Alice);
        wadjet.reinvest();

        // 你的后续攻击逻辑继续搬过来
        console.log("pool:", wadjet.getBalance());
    }
}