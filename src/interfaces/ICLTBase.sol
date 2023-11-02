//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface ICLTBase {
    error NoLiquidity();
    error InvalidInput();
    error InvalidShare();
    error InvalidCaller();
    error onlyNonCompounders();
    error TransactionTooAged();
    error InvalidModule(bytes32 module);

    /// @param pool The Uniswap V3 pool
    /// @param tickLower The lower tick of the A51's LP position
    /// @param tickUpper The upper tick of the A51's LP position
    struct StrategyKey {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @param modeIDs Array of ids for each the basic or advance strategy
    /// @param modesVault Address of the base or adnvace mode vault
    struct ModePackage {
        uint256[] modeIDs;
        address modesVault;
    }

    /// @param mode ModuleId: one of four basic modes 1: left, 2: Right, 3: Both, 4: Static
    /// @param exitStrategy Array of whitelistd ids for advance mode exit strategy selection
    /// @param rebaseStrategy Array of whitelistd ids for advance mode rebase strategy selection
    /// @param liquidityDistribution Array of whitelistd ids for advance mode liquidity distribution selection
    struct PositionActions {
        uint256 mode;
        uint256[] exitStrategy;
        uint256[] rebaseStrategy;
        uint256[] liquidityDistribution;
    }

    /// @param exitStrategy Array of inputs as encoded data for exit strategies
    /// @param rebaseStrategy Array of inputs as encoded data for rebase strategies
    /// @param liquidityDistribution Array of inputs as encoded data for liquidity distribution strategies
    struct ActionsData {
        bytes[] exitStrategyData;
        bytes[] rebaseStrategyData;
        bytes[] liquidityDistributionData;
    }

    /// @param key A51 position's key details
    /// @param actions Ids of all modes selected by the strategist encoded together in a single hash
    /// @param actionsData Input values for the respective mode encoded in hash & all inputs are encoded together again
    /// @param actionStatus The encoded data for each of the strategy to track any detail for futher actions
    /// @param isCompound Bool weather the strategy has compunding activated or not
    /// @param balance0 Amount of token0 left that are not added on AMM's position
    /// @param balance1 Amount of token0 left that are not added on AMM's position
    /// @param totalShares Total no of shares minted for this A51's strategy
    /// @param uniswapLiquidity Total no of liquidity added on AMM for this strategy
    /// @param feeGrowthInside0LastX128 The fee growth of token0 collected per unit of liquidity for
    /// the entire life of the A51's position
    /// @param feeGrowthInside1LastX128 The fee growth of token1 collected per unit of liquidity for
    /// the entire life of the A51's position
    struct StrategyData {
        StrategyKey key;
        bytes actions;
        bytes actionsData; // assembly operations needed to merge actions & data into single byte32 word { figure out }
        bytes actionStatus;
        bool isCompound;
        uint256 balance0;
        uint256 balance1;
        uint256 totalShares;
        uint128 uniswapLiquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

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

    /// @notice Emitted when strategy is created
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param positionActions It is a hash of a preimage composed by all modes IDs selected by the strategist
    /// @param actionsData It is a hash of a preimage composed by all inputs of respective mode
    /// @param key A51 position's key details associated with this strategy
    /// @param isCompound Bool weather the strategy has compunding activated or not
    event StrategyCreated(
        bytes32 strategyId, bytes positionActions, bytes actionsData, StrategyKey key, bool isCompound
    );

    /// @notice Creates new LP strategy on AMM
    /// @dev Call this when the pool does exist and is initialized
    /// List of whitelisted IDs could be fetched by the modules function for each basic & advance mode.
    /// If any ID is selected of any module it is mandatory to encode data for it then pass it to actions array
    /// E.g: actions: [1, 3], it's should be: actionsData: [dataOfID1, dataOfID2]
    /// otherwise it will revert
    /// @param key The params necessary to select a position, encoded as `StrategyKey` in calldata
    /// @param data It is a hash of all inputs of respective modes
    /// @param actions It is hash of all encoded data of whitelisted IDs which are being passed
    /// @param isCompound Bool weather the strategy should have compunding activated or not
    function createStrategy(
        StrategyKey calldata key,
        PositionActions calldata actions,
        ActionsData calldata data,
        bool isCompound
    )
        external;

    /// @notice Returns the information about a strategy by the strategy's key
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @return key A51 position's key details associated with this strategy
    /// @return actions It is a hash of a preimage composed by all modes IDs selected by the strategist
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

    /// @param amount0Desired The desired amount of token0 to be spent,
    /// @param amount1Desired The desired amount of token1 to be spent,
    /// @param amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
    /// @param amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
    /// @param recipient account that should receive the shares in terms of A51's NFT
    struct DepositParams {
        bytes32 strategyId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
    }

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

    /// @param params tokenId The ID of the token for which liquidity is being increased
    /// @param amount0Desired The desired amount of token0 to be spent,
    /// @param amount1Desired The desired amount of token1 to be spent,
    struct UpdatePositionParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
    }

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params The params necessary to increase a position, encoded as `UpdatePositionParams` in calldata
    /// @dev This method can be used by by both compounding & non-compounding strategy positions
    /// @return share The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function updatePositionLiquidity(UpdatePositionParams calldata params)
        external
        returns (uint256 share, uint256 amount0, uint256 amount1);

    /// @param params tokenId The ID of the token for which liquidity is being decreased
    /// @param liquidity amount The amount by which liquidity will be decreased,
    /// @param recipient Recipient of tokens
    /// @param refundAsETH whether to recieve in WETH or ETH (only valid for WETH/ALT pairs)
    struct WithdrawParams {
        uint256 tokenId;
        uint256 liquidity;
        address recipient;
        bool refundAsETH;
    }

    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param params The params necessary to decrease a position, encoded as `WithdrawParams` in calldata
    /// @return amount0 Amount of token0 sent to recipient
    /// @return amount1 Amount of token1 sent to recipient
    function withdraw(WithdrawParams calldata params) external returns (uint256 amount0, uint256 amount1);

    /// @param recipient Recipient of tokens
    /// @param params tokenId The ID of the NFT for which tokens are being collected
    /// @param refundAsETH whether to recieve in WETH or ETH (only valid for WETH/ALT pairs)
    struct ClaimFeesParams {
        address recipient;
        uint256 tokenId;
        bool refundAsETH;
    }

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @dev Only non-compounding strategy users can call this
    /// @param params The params necessary to collect a position uncompounded fee, encoded as `ClaimFeesParams` in
    /// calldata
    function claimPositionFee(ClaimFeesParams calldata params) external;

    /// @param key A51 new position's key with updated ticks
    /// @param strategyId Id of A51's position for which ticks are being updated
    /// @param shouldMint Bool weather liquidity should be added on AMM or hold in contract
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param swapAmount The amount of the swap, which implicitly configures the swap as exact input (positive), or
    /// exact
    /// output (negative)
    /// @param moduleStatus The encoded data for each of the strategy to track any detail for futher actions
    struct ShiftLiquidityParams {
        StrategyKey key;
        bytes32 strategyId;
        bool shouldMint;
        bool zeroForOne;
        int256 swapAmount;
        bytes moduleStatus;
    }

    /// @notice Updates the strategy's liquidity accordingly w.r.t basic or advance module when it is activated
    /// @dev Only called by the whitlisted bot or owner of strategy
    /// @param params The params necessary to update a position, encoded as `ShiftLiquidityParams` in calldata
    function shiftLiquidity(ShiftLiquidityParams calldata params) external;
}
