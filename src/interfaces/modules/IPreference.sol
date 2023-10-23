// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface IPreference {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();

    struct StrategyData {
        bytes32 strategyID;
        uint64[3] modes; // Array to hold multiple valid modes
    }
}
