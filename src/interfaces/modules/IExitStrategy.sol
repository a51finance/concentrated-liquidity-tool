// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../ICLTBase.sol";

interface IExitStrategy {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();
    error InvalidMode();
    error InvalidStrategyId(bytes32);
    error InvalidRebalanceThresholdDifference();
    error StrategyIdsCannotBeEmpty();
    error StrategyIdCannotBeZero();
    error DuplicateStrategyId(bytes32);
    error StrategyIdDonotExist(bytes32);
    error InvalidExitPreference();
    error ExitStrategyDataCannotBeZero();

    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param mode ModuleId: one of four basic modes 1: left, 2: Right, 3: Both, 4: Static
    /// @param actionNames to hold multiple valid modes
    struct ExecutableStrategiesData {
        bytes32 strategyID;
        uint256 mode;
        bytes32[1] actionNames;
    }

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}
