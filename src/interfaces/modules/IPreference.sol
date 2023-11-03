// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

interface IPreference {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();
    error InvalidMode();
    error InvalidPreferenceDifference();
    error InvalidTimePreference();
    error StrategyIdsCannotBeEmpty();
    error StrategyIdCannotBeZero();
    error DuplicateStrategyId(bytes32 strategyId);
    error TimePreferenceConstraint();
    error BothTicksCannotBeZero();
    error RebaseStrategyDataCannotBeZero();
    error OnlyRebaseInactivityCannotBeSelected();
    error RebaseInactivityCannotBeZero();

    struct StrategyData {
        bytes32 strategyID;
        uint256[3] modes; // Array to hold multiple valid modes
    }

    enum Mode {
        DUMMY,
        REBASE_PREFERENCE,
        REBASE_TIME_PREFERENCE,
        REBASE_INACTIVITY
    }

    function checkInputData(bytes[] memory data) external returns (bool);

    event Executed(StrategyData[] strategyIds);
}
