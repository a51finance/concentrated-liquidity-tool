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
    error InvalidModuleAction(bytes32 actionName);
    error InvalidModule(bytes32 module);

    /// @notice Emitted when tokens are collected for a position NFT
    /// @param tokenId The ID of the token for which underlying tokens were collected
    /// @param recipient The address of the account that received the collected tokens
    /// @param amount0Collected The amount of token0 owed to the position that was collected
    /// @param amount1Collected The amount of token1 owed to the position that was collected
    event Collect(uint256 tokenId, address recipient, uint256 amount0Collected, uint256 amount1Collected);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param tokenId The ID of the token for which liquidity was increased
    /// @param recipient Recipient of liquidity
    /// @param liquidity The amount by which liquidity for the NFT position was increased
    /// @param amount0 The amount of token0 that was paid for the increase in liquidity
    /// @param amount1 The amount of token1 that was paid for the increase in liquidity
    event Deposit(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @param tokenId The ID of the token for which liquidity was decreased
    /// @param recipient Recipient of liquidity
    /// @param liquidity The amount by which liquidity for the NFT position was decreased
    /// @param amount0 The amount of token0 that was accounted for the decrease in liquidity
    /// @param amount1 The amount of token1 that was accounted for the decrease in liquidity
    event Withdraw(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param strategyId a parameter just like in doxygen (must be followed by parameter name)
    event StrategyCreated(bytes32 strategyId, bytes actionsData, StrategyKey key, bool isCompound);

    /// @notice Creates new LP strategy on AMM
    /// @dev Call this when the pool does exist and is initialized
    /// @param key The params necessary to select a position, encoded as `StrategyKey` in calldata
    /// ......
    function createStrategy(StrategyKey calldata key, ActionDetails calldata details, bool isCompound) external;

    /// @notice Returns the information about a strategy by the strategy's key
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @return key A51 position's key details associated with this strategy
    /// @return actionsData It is a hash of a preimage composed by all inputs of respective mode
    /// @return actionStatus It is a hash of a additional data of strategy for further required actions
    /// @return isCompound Bool weather the strategy has compunding activated or not
    /// @return balance0 Amount of token0 left that are not added on AMM's position
    /// @return balance1 Amount of token0 left that are not added on AMM's position
    /// @return totalShares Total no of shares minted for this A51's strategy
    /// @return uniswapLiquidity Total no of liquidity added on AMM for this strategy
    /// @return feeGrowthInside0LastX128 The fee growth of token0 collected per unit of liquidity for
    /// the entire life of the A51's position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 collected per unit of liquidity for
    /// the entire life of the A51's position
    function strategies(bytes32 strategyId)
        external
        returns (
            StrategyKey memory key,
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

    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param positionId The ID of the token that represents the position
    /// @return strategyId strategy ID assigned to this token ID
    /// @return liquidityShare Shares assigned to this token ID
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
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

    /// @notice Creates a new position wrapped in a A51 NFT
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function deposit(DepositParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params The params necessary to increase a position, encoded as `UpdatePositionParams` in calldata
    /// @dev This method can be used by by both compounding & non-compounding strategy positions
    /// @return share The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function updatePositionLiquidity(UpdatePositionParams calldata params)
        external
        returns (uint256 share, uint256 amount0, uint256 amount1);

    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param params The params necessary to decrease a position, encoded as `WithdrawParams` in calldata
    /// @return amount0 Amount of token0 sent to recipient
    /// @return amount1 Amount of token1 sent to recipient
    function withdraw(WithdrawParams calldata params) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @dev Only non-compounding strategy users can call this
    /// @param params The params necessary to collect a position uncompounded fee, encoded as `ClaimFeesParams` in
    /// calldata
    function claimPositionFee(ClaimFeesParams calldata params) external;

    /// @notice Explain to an end user what this does
    /// @param params The params necessary to update a position, encoded as `ShiftLiquidityParams` in calldata
    function shiftLiquidity(ShiftLiquidityParams calldata params) external;
}
