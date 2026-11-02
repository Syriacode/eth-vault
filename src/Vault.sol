// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Vault
/// @notice Deposit ETH and withdraw it later. Each user can only withdraw their own balance.
contract Vault {
    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error ZeroAmount();
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        // Checks
        if (amount == 0) revert ZeroAmount();
        uint256 available = balanceOf[msg.sender];
        if (amount > available) revert InsufficientBalance(amount, available);
        // Effects
        balanceOf[msg.sender] = available - amount;
        emit Withdrawn(msg.sender, amount);
        // Interactions
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function withdrawAll() external {
        // Checks
        uint256 amount = balanceOf[msg.sender];
        if (amount == 0) revert ZeroAmount();
        // Effects
        balanceOf[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        // Interactions
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // No receive() or fallback(): plain ETH transfers to this contract revert.
}
