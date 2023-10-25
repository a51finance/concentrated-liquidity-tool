// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface IPreference {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();
    error InvalidMode();
    error StrategyIdsCannotBeEmpty();
    error StrategyIdCannotBeZero();
    error DuplicateStrategyId(bytes32 strategyId);
    error timePreferenceConstraint();

    struct StrategyData {
        bytes32 strategyID;
        uint64[3] modes; // Array to hold multiple valid modes
    }

    function checkInputData(bytes[] memory data) external;

    event Executed(bytes32[] strategyIds);
}
