// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface IPreference {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();
    error InvalidMode();
    error InvalidPreferenceDifference();
    error StrategyIdsCannotBeEmpty();
    error StrategyIdCannotBeZero();
    error DuplicateStrategyId(bytes32 strategyId);
    error TimePreferenceConstraint();
    error BothTicksCannotBeZero();
    error RebaseStrategyDataCannotBeZero();

    struct StrategyData {
        bytes32 strategyID;
        uint256[3] modes; // Array to hold multiple valid modes
    }

    function checkInputData(bytes[] memory data) external returns (bool);

    event Executed(StrategyData[] strategyIds);
}
