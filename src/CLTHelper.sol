// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.15;

struct StrategyPayload {
    bytes32 actionName;
    bytes data;
}

struct PositionActions {
    uint256 mode;
    StrategyPayload[] exitStrategy;
    StrategyPayload[] rebaseStrategy;
    StrategyPayload[] liquidityDistribution;
}

contract CLTHelper {
    function decodePositionActions(bytes memory actions) external pure returns (PositionActions memory) {
        PositionActions memory modules = abi.decode(actions, (PositionActions));
        return modules;
    }
}
