// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "../ICLTBase.sol";

interface IRebaseStrategy {
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
    error BothTicksCannotBeZero();
    error RebaseStrategyDataCannotBeZero();
    error OnlyRebaseInactivityCannotBeSelected();
    error RebaseInactivityCannotBeZero();
    error SwapsThresholdExceeded();
    error SlippageThresholdExceeded();

    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param mode ModuleId: one of four basic modes 1: left, 2: Right, 3: Both, 4: Static
    /// @param actionNames to hold multiple valid modes
    struct ExecutableStrategiesData {
        bytes32 strategyID;
        uint256 mode;
        bytes32[3] actionNames;
    }

    /// @notice Structure to hold the processing details of a strategy.
    /// @param hasRebaseInactivity Indicates if the strategy has rebase inactivity.
    /// @param rebaseCount The number of times the strategy has been rebased.
    /// @param manualSwapsCount The number of manual swaps performed for the strategy.
    /// @param lastUpdateTimeStamp The timestamp of the last update to the strategy.
    struct StrategyProcessingDetails {
        bool hasRebaseInactivity;
        uint256 rebaseCount;
        uint256 manualSwapsCount;
        uint256 lastUpdateTimeStamp;
    }

    /// @notice Checks the validity of input data for a strategy.
    /// @param data The strategy payload to be checked.
    /// @return True if the input data is valid, false otherwise.
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

    /// @notice Structure to hold the parameters for swap amounts in a strategy.
    /// @param amount0Desired The desired amount of token0 for the swap.
    /// @param amount1Desired The desired amount of token1 for the swap.
    /// @param newAmount0 The new amount of token0 after the swap.
    /// @param newAmount1 The new amount of token1 after the swap.
    /// @param strategyFee0 The fee for token0 associated with the strategy.
    /// @param strategyFee1 The fee for token1 associated with the strategy.
    /// @param protocolFee0 The protocol fee for token0.
    /// @param protocolFee1 The protocol fee for token1.
    struct SwapAmountsParams {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 newAmount0;
        uint256 newAmount1;
        uint256 strategyFee0;
        uint256 strategyFee1;
        uint256 protocolFee0;
        uint256 protocolFee1;
    }

    event Executed(ExecutableStrategiesData[] strategyIds);
}
