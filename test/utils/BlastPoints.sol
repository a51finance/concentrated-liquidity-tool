// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract BlastPoints {
    event PointsOperator(address contractAddress, address operatorAddress);

    mapping(address => address) public operators;
    address constant BANNED_ADDRESS = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

    function configurePointsOperator(address operatorAddress) external {
        configurePointsOperatorInternal(msg.sender, operatorAddress);
    }

    function configurePointsOperatorInternal(address contractAddress, address newOperatorAddress) internal {
        require(newOperatorAddress != BANNED_ADDRESS, "Invalid operator");

        address oldOperatorAddress = operators[contractAddress];
        require(oldOperatorAddress != BANNED_ADDRESS, "Contract banned");

        address authorizedSender = oldOperatorAddress != address(0) ? oldOperatorAddress : contractAddress;
        require(authorizedSender == msg.sender, "Unauthorized sender");

        setAndEmitOperator(contractAddress, newOperatorAddress);
    }

    function setAndEmitOperator(address contractAddress, address operatorAddress) internal {
        operators[contractAddress] = operatorAddress;
        emit PointsOperator(contractAddress, operatorAddress);
    }
}
