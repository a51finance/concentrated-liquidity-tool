//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../base/Structs.sol";

interface ICLTBase {
    error NoLiquidity();
    error InvalidShare();
    error InvalidCaller();
    error onlyNonCompounders();
    error TransactionTooAged();
    error InvalidModule(bytes32 module);

    event Collect(uint256 tokenId, address recipient, uint256 amount0Collected, uint256 amount1Collected);
    event Deposit(bytes32 strategyId, uint256 indexed tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    event StrategyCreated(
        bytes32 strategyId, bytes positionActions, bytes actionsData, StrategyKey key, bool isCompound
    );

    function deposit(DepositParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    function withdraw(WithdrawParams calldata params) external returns (uint256 amount0, uint256 amount1);

    function claimPositionFee(ClaimFeesParams calldata params) external;

    function shiftLiquidity(ShiftLiquidityParams calldata params) external;
}
