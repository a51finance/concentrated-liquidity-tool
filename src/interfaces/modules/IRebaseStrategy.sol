// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "../ICLTBase.sol";

interface IRebaseStrategy {
    error InvalidCaller();
    error InvalidThreshold();
    error InvalidModesLength();
    error InvalidMode();
    error InvalidStrategyId(bytes32);
    error InvalidPricePreferenceDifference();
    error StrategyIdsCannotBeEmpty();
    error StrategyIdCannotBeZero();
    error DuplicateStrategyId(bytes32);
    error StrategyIdDonotExist(bytes32);
    error BothTicksCannotBeZero();
    error RebaseStrategyDataCannotBeZero();
    error OnlyRebaseInactivityCannotBeSelected();
    error RebaseInactivityCannotBeZero();

    struct ExecutableStrategiesData {
        bytes32 strategyID;
        uint256 mode;
        bytes32[2] actionNames; // Array to hold multiple valid modes
    }

    struct StrategyInputData {
        bytes32 strategyID;
        bytes rebaseOptions;
    }

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);

    struct ExectuteStrategyParams {
        IUniswapV3Pool pool;
        bytes32 strategyID;
        int24 tickLower;
        int24 tickUpper;
        bool shouldMint;
        bool zeroForOne;
        int256 swapAmount;
        uint160 sqrtPriceLimitX96;
    }

    event Executed(ExecutableStrategiesData[] strategyIds);
}
