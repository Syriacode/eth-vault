// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    Vault internal vault;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        vault = new Vault();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // 1
    function test_Deposit_UpdatesBalancesAndEmits() public {
        vm.expectEmit(address(vault));
        emit Vault.Deposited(alice, 1 ether);

        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(address(vault).balance, 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    // 2
    function test_Deposit_RevertsOnZero() public {
        vm.expectRevert(Vault.ZeroAmount.selector);
        vm.prank(alice);
        vault.deposit{value: 0}();
    }

    // 3
    function test_Withdraw_SendsEthAndEmits() public {
        vm.startPrank(alice);
        vault.deposit{value: 2 ether}();

        vm.expectEmit(address(vault));
        emit Vault.Withdrawn(alice, 1 ether);
        vault.withdraw(1 ether);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(address(vault).balance, 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    // 4
    function test_Withdraw_RevertsWhenMoreThanBalance() public {
        vm.startPrank(alice);
        vault.deposit{value: 1 ether}();

        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 2 ether, 1 ether));
        vault.withdraw(2 ether);
        vm.stopPrank();
    }

    // 5
    function test_Withdraw_BobCannotTakeAlicesEth() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.expectRevert(abi.encodeWithSelector(Vault.InsufficientBalance.selector, 1 ether, 0));
        vm.prank(bob);
        vault.withdraw(1 ether);

        assertEq(vault.balanceOf(alice), 1 ether);
    }

    // 6
    function test_WithdrawAll_EmptiesBalance() public {
        vm.startPrank(alice);
        vault.deposit{value: 3 ether}();
        vault.withdrawAll();
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(address(vault).balance, 0);
        assertEq(alice.balance, 10 ether);
    }

    // 7
    function test_DirectEthTransfer_Fails() public {
        vm.prank(alice);
        (bool ok,) = address(vault).call{value: 1 ether}("");

        assertFalse(ok);
        assertEq(address(vault).balance, 0);
        assertEq(alice.balance, 10 ether);
    }

    // 8
    function testFuzz_DepositThenWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1, 10 ether);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.startPrank(alice);
        vault.deposit{value: depositAmount}();
        vault.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), depositAmount - withdrawAmount);
        assertEq(address(vault).balance, depositAmount - withdrawAmount);
        assertEq(alice.balance, 10 ether - depositAmount + withdrawAmount);
    }
}
