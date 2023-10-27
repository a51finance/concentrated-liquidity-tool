//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../base/Structs.sol";

interface ICLTBase {
    error NoLiquidity();
    error InvalidInput();
    error InvalidShare();
    error InvalidCaller();
    error onlyNonCompounders();
    error TransactionTooAged();
    error InvalidModule(bytes32 module);

    event Collect(uint256 tokenId, address recipient, uint256 amount0Collected, uint256 amount1Collected);

    event Deposit(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    event Withdraw(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    event StrategyCreated(
        bytes32 strategyId, bytes positionActions, bytes actionsData, StrategyKey key, bool isCompound
    );

    function strategies(bytes32 strategyId)
        external
        returns (
            StrategyKey memory key,
            bytes memory actions,
            bytes memory actionsData,
            bytes memory actionStatus,
            bool isCompound,
            uint256 balance0,
            uint256 balance1,
            uint256 totalShares,
            uint128 uniswapLiquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128
        );

    function positions(uint256 positionId)
        external
        returns (
            bytes32 strategyId,
            uint256 liquidityShare,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function deposit(DepositParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    function withdraw(WithdrawParams calldata params) external returns (uint256 amount0, uint256 amount1);

    function claimPositionFee(ClaimFeesParams calldata params) external;

    function shiftLiquidity(ShiftLiquidityParams calldata params) external;
}
