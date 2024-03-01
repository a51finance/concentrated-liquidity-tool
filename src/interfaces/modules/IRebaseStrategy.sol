// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "../ICLTBase.sol";

interface IRebaseStrategy {
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
        IAlgebraPool pool;
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
