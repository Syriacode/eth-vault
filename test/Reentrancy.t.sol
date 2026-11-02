// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract Attacker {
    Vault public immutable vault;

    constructor(Vault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdrawAll();
    }

    // Runs when the vault sends ETH: try to withdraw again before the first withdrawAll finishes.
    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdrawAll();
        }
    }
}

contract ReentrancyTest is Test {
    Vault internal vault;
    Attacker internal attacker;
    address internal alice = makeAddr("alice");

    function setUp() public {
        vault = new Vault();
        attacker = new Attacker(vault);

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        vault.deposit{value: 10 ether}();
    }

    function test_ReentrancyAttackFails() public {
        try attacker.attack{value: 1 ether}() {} catch {}

        assertEq(address(vault).balance, 10 ether, "vault was drained");
        assertEq(address(attacker).balance, 0, "attacker kept stolen ETH");
    }
}
