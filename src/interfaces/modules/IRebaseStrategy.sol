// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "../ICLTBase.sol";

interface IRebaseStrategy {
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param mode ModuleId: one of four basic modes 1: left, 2: Right, 3: Both, 4: Static
    /// @param actionNames to hold multiple valid modes
    struct ExecutableStrategiesData {
        bytes32 strategyID;
        uint256 mode;
        bytes32[2] actionNames;
    }

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);

    /// @param pool The Uniswap V3 pool
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param tickLower The lower tick of the A51's LP position
    /// @param tickUpper The upper tick of the A51's LP position
    /// @param tickLower The lower tick of the A51's LP position
    /// @param shouldMint Bool weather liquidity should be added on AMM or hold in contract
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param swapAmount The amount of the swap, which implicitly configures the swap as exact input (positive), or
    /// exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this

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
