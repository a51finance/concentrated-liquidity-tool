// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15 >=0.5.0 >=0.8.0;

// lib/solmate/src/auth/Owned.sol

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolErrors.sol

/// @title Errors emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolErrors {
    error LOK();
    error TLU();
    error TLM();
    error TUM();
    error AI();
    error M0();
    error M1();
    error AS();
    error IIA();
    error L();
    error F0();
    error F1();
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolEvents.sol

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolOwnerActions.sol

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

// lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolState.sol

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// @return tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// @return observationIndex The index of the last oracle observation that was written,
    /// @return observationCardinality The current maximum number of observations stored in the pool,
    /// @return observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// @return feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    /// @return The liquidity at the current price of the pool
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper
    /// @return liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// @return feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// @return feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// @return tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// @return secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// @return secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// @return initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return liquidity The amount of liquidity in the position,
    /// @return feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// @return feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// @return tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// @return tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// @return tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// @return secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// @return initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

// src/interfaces/IGovernanceFeeHandler.sol

interface IGovernanceFeeHandler {
    error StrategyFeeLimitExceed();
    error ManagementFeeLimitExceed();
    error PerformanceFeeLimitExceed();
    error LPAutomationFeeLimitExceed();

    /// @param lpAutomationFee The value of fee applied for automation of strategy
    /// @param strategyCreationFee The value of fee applied for creation of new strategy
    /// @param protcolFeeOnManagement  The value of fee applied on strategiest earned fee on managment of strategy
    /// @param protcolFeeOnPerformance The value of fee applied on strategiest earned fee on performance of strategy
    struct ProtocolFeeRegistry {
        uint256 lpAutomationFee;
        uint256 strategyCreationFee;
        uint256 protcolFeeOnManagement;
        uint256 protcolFeeOnPerformance;
    }

    /// @notice Returns the protocol fee value
    /// @param isPrivate Bool value weather strategy is private or public
    function getGovernanceFee(bool isPrivate)
        external
        view
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        );

    /// @notice Updates the protocol fee value for public strategy
    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry) external;

    /// @notice Updates the protocol fee value for private strategy
    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry) external;

    /// @notice Emitted when the protocol fee for public strategy has been updated
    event PublicFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);

    /// @notice Emitted when the protocol fee for private strategy has been updated
    event PrivateFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);
}

// src/libraries/Constants.sol

library Constants {
    uint256 public constant WAD = 1e18;

    uint256 public constant MIN_INITIAL_SHARES = 1e3;

    uint256 public constant MAX_MANAGEMENT_FEE = 2e17;

    uint256 public constant MAX_PERFORMANCE_FEE = 2e17;

    uint256 public constant MAX_PROTCOL_MANAGEMENT_FEE = 2e17;

    uint256 public constant MAX_PROTCOL_PERFORMANCE_FEE = 2e17;

    uint256 public constant MAX_AUTOMATION_FEE = 2e17;

    uint256 public constant MAX_STRATEGY_CREATION_FEE = 5e17;

    uint128 public constant MAX_UINT128 = type(uint128).max;

    // keccak256("MODE")
    bytes32 public constant MODE = 0x25d202ee31c346b8c1099dc1a469d77ca5ac14ed43336c881902290b83e0a13a;

    // keccak256("EXIT_STRATEGY")
    bytes32 public constant EXIT_STRATEGY = 0xf36a697ed62dd2d982c1910275ee6172360bf72c4dc9f3b10f2d9c700666e227;

    // keccak256("REBASE_STRATEGY")
    bytes32 public constant REBASE_STRATEGY = 0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204;

    // keccak256("LIQUIDITY_DISTRIBUTION")
    bytes32 public constant LIQUIDITY_DISTRIBUTION = 0xeabe6f62bd74d002b0267a6aaacb5212bb162f4f87ee1c4a80ac0d2698f8a505;
}

// lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolErrors,
    IUniswapV3PoolEvents
{

}

// src/interfaces/ICLTBase.sol

interface ICLTBase {
    error NoLiquidity();
    error InvalidInput();
    error InvalidShare();
    error InvalidCaller();
    error onlyNonCompounders();
    error TransactionTooAged();
    error MinimumAmountsExceeded();
    error OwnerCannotBeZeroAddress();

    /// @param pool The Uniswap V3 pool
    /// @param tickLower The lower tick of the A51's LP position
    /// @param tickUpper The upper tick of the A51's LP position
    struct StrategyKey {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @param actionName Encoded name of whitelisted advance module
    /// @param data input as encoded data for selected module
    struct StrategyPayload {
        bytes32 actionName;
        bytes data;
    }

    /// @param mode ModuleId: one of four basic modes 1: left, 2: Right, 3: Both, 4: Static
    /// @param exitStrategy Array of whitelistd ids for advance mode exit strategy selection
    /// @param rebaseStrategy Array of whitelistd ids for advance mode rebase strategy selection
    /// @param liquidityDistribution Array of whitelistd ids for advance mode liquidity distribution selection
    struct PositionActions {
        uint256 mode;
        StrategyPayload[] exitStrategy;
        StrategyPayload[] rebaseStrategy;
        StrategyPayload[] liquidityDistribution;
    }

    /// @param fee0 Amount of fees0 collected by strategy
    /// @param fee1 Amount of fees1 collected by strategy
    /// @param balance0 Amount of token0 left in strategy that were not added in pool
    /// @param balance1 Amount of token1 left in strategy that were not added in pool
    /// @param totalShares Total no of shares minted for this A51's strategy
    /// @param uniswapLiquidity Total no of liquidity added on AMM for this strategy
    /// @param feeGrowthInside0LastX128 The fee growth of token0 collected per unit of liquidity for
    /// the entire life of the A51's position
    /// @param feeGrowthInside1LastX128 The fee growth of token1 collected per unit of liquidity for
    /// the entire life of the A51's position
    struct Account {
        uint256 fee0;
        uint256 fee1;
        uint256 balance0;
        uint256 balance1;
        uint256 totalShares;
        uint128 uniswapLiquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 feeGrowthOutside0LastX128;
        uint256 feeGrowthOutside1LastX128;
    }

    /// @param key A51 position's key details
    /// @param owner The address of the strategy owner
    /// @param actions Ids of all modes selected by the strategist encoded together in a single hash
    /// @param actionStatus The encoded data for each of the strategy to track any detail for futher actions
    /// @param isCompound Bool weather the strategy has compunding activated or not
    /// @param isPrivate Bool weather strategy is open for all users or not
    /// @param managementFee  The value of fee in percentage applied on strategy users liquidity by strategy owner
    /// @param performanceFee The value of fee in percentage applied on strategy users earned fee by strategy owner
    /// @param account Strategy accounts of balances and fee account details
    struct StrategyData {
        StrategyKey key;
        address owner;
        bytes actions;
        bytes actionStatus;
        bool isCompound;
        bool isPrivate;
        uint256 managementFee;
        uint256 performanceFee;
        Account account;
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
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );

    /// @notice Emitted when strategy is created
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    event StrategyCreated(bytes32 indexed strategyId);

    /// @notice Emitted when data of strategy is updated
    /// @param strategyId Hash of strategy ID
    event StrategyUpdated(bytes32 indexed strategyId);

    /// @notice Emitted when fee of strategy is collected
    /// @param strategyId Hash of strategy ID
    /// @param fee0 Amount of fees0 collected by strategy
    /// @param fee1 Amount of fees1 collected by strategy
    event StrategyFee(bytes32 indexed strategyId, uint256 fee0, uint256 fee1);

    /// @notice Emitted when liquidity is increased for a position NFT
    /// @param tokenId The ID of the token for which liquidity was increased
    /// @param share The amount by which liquidity for the NFT position was increased
    /// @param amount0 The amount of token0 that was paid for the increase in liquidity
    /// @param amount1 The amount of token1 that was paid for the increase in liquidity
    event PositionUpdated(uint256 indexed tokenId, uint256 share, uint256 amount0, uint256 amount1);

    /// @notice Emitted when strategy position is updated or shifted
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @param isLiquidityMinted Bool whether the new liquidity position is minted in pool or HODL in contract
    /// @param zeroForOne Bool The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param swapAmount The amount of the swap, which implicitly configures the swap as exact input (positive), or
    /// exact output (negative)
    event LiquidityShifted(bytes32 indexed strategyId, bool isLiquidityMinted, bool zeroForOne, int256 swapAmount);

    /// @notice Emitted when collected fee of strategy is compounded
    /// @param strategyId Hash of strategy ID
    /// @param amount0 The amount of token0 that were compounded
    /// @param amount1 The amount of token1 that were compounded
    event FeeCompounded(bytes32 indexed strategyId, uint256 amount0, uint256 amount1);

    /// @notice Creates new LP strategy on AMM
    /// @dev Call this when the pool does exist and is initialized
    /// List of whitelisted IDs could be fetched by the modules contract for each basic & advance mode.
    /// If any ID is selected of any module it is mandatory to encode data for it then pass it to StrategyPayload.data
    /// @param key The params necessary to select a position, encoded as `StrategyKey` in calldata
    /// @param actions It is hash of all encoded data of whitelisted IDs which are being passed
    /// @param managementFee  The value of fee in percentage applied on strategy users liquidity by strategy owner
    /// @param performanceFee The value of fee in percentage applied on strategy users earned fee by strategy owner
    /// @param isCompound Bool weather the strategy should have compunding activated or not
    /// @param isPrivate Bool weather strategy is open for all users or not
    function createStrategy(
        StrategyKey calldata key,
        PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee,
        bool isCompound,
        bool isPrivate
    )
        external
        payable;

    /// @notice Returns the information about a strategy by the strategy's key
    /// @param strategyId The strategy's key is a hash of a preimage composed by the owner & token ID
    /// @return key A51 position's key details associated with this strategy
    /// @return owner The address of the strategy owner
    /// @return actions It is a hash of a preimage composed by all modes IDs selected by the strategist
    /// @return actionStatus It is a hash of a additional data of strategy for further required actions
    /// @return isCompound Bool weather the strategy has compunding activated or not
    /// @return isPrivate Bool weather strategy is open for all users or not
    /// @return managementFee The value of fee in percentage applied on strategy users liquidity by strategy owner
    /// @return performanceFee The value of fee in percentage applied on strategy users earned fee by strategy owner
    /// @return account Strategy values of balances and fee accounting details
    function strategies(bytes32 strategyId)
        external
        returns (
            StrategyKey memory key,
            address owner,
            bytes memory actions,
            bytes memory actionStatus,
            bool isCompound,
            bool isPrivate,
            uint256 managementFee,
            uint256 performanceFee,
            Account memory account
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
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params The params necessary to increase a position, encoded as `UpdatePositionParams` in calldata
    /// @dev This method can be used by by both compounding & non-compounding strategy positions
    /// @return share The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function updatePositionLiquidity(UpdatePositionParams calldata params)
        external
        payable
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
        uint256 amount0Min;
        uint256 amount1Min;
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
    /// exact output (negative)
    /// @param moduleStatus The encoded data for each of the strategy to track any detail for futher actions
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    struct ShiftLiquidityParams {
        StrategyKey key;
        bytes32 strategyId;
        bool shouldMint;
        bool zeroForOne;
        int256 swapAmount;
        bytes moduleStatus;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Updates the strategy's liquidity accordingly w.r.t basic or advance module when it is activated
    /// @dev Only called by the whitlisted bot or owner of strategy
    /// @param params The params necessary to update a position, encoded as `ShiftLiquidityParams` in calldata
    function shiftLiquidity(ShiftLiquidityParams calldata params) external;
}

// src/interfaces/ICLTModules.sol

interface ICLTModules {
    error InvalidMode();
    error InvalidStrategy();
    error InvalidStrategyAction();

    /// @notice Validates the strategy inputs
    /// @param actions The ids of all actions selected for new strategy creation
    /// @param managementFee  The value of strategist management fee on strategy
    /// @param performanceFee The value of strategist perofrmance fee on strategy
    function validateModes(
        ICLTBase.PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee
    )
        external;
}

// src/interfaces/modules/IExitStrategy.sol

interface IExitStrategy {
    error InvalidCaller();

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}

// src/interfaces/modules/ILiquidityDistributionStrategy.sol

interface ILiquidityDistributionStrategy {
    error InvalidCaller();

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}

// src/interfaces/modules/IRebaseStrategy.sol

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
    error SwapsThresholdExceeded();

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

// src/CLTModules.sol

/// @title  CLTModules
/// @notice CLTModules contains methods for managing modes and it's actions for strategy
contract CLTModules is ICLTModules, Owned {
    mapping(bytes32 => address) public modeVaults;

    mapping(bytes32 => mapping(bytes32 => bool)) public modulesActions;

    constructor(address owner) Owned(owner) { }

    /// @notice Whitlist new ids for advance strategy modes
    /// @dev New id can only be added for only rebase, exit & liquidity advance modes
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param newModule Array of new mode ids to be added against advance modes
    function setNewModule(bytes32 moduleKey, bytes32 newModule) external onlyOwner {
        _checkModuleKey(moduleKey);

        modulesActions[moduleKey][newModule] = true;
    }

    /// @notice updates the address of mode's vault
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param modeVault New address of mode's vault
    function setModuleAddress(bytes32 moduleKey, address modeVault) external onlyOwner {
        _checkModuleKey(moduleKey);

        modeVaults[moduleKey] = modeVault;
    }

    /// @notice Turn on or off any mode of strategy
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param module Hash of the module action for which is need to be updated
    function toggleModule(bytes32 moduleKey, bytes32 module) external onlyOwner {
        _checkModuleKey(moduleKey);

        modulesActions[moduleKey][module] = !modulesActions[moduleKey][module];
    }

    /// @notice Validates the strategy encoded input data
    function _validateInputData(bytes32 mode, ICLTBase.StrategyPayload[] memory array) private {
        address vault = modeVaults[mode];

        for (uint256 i = 0; i < array.length; i++) {
            if (mode == Constants.REBASE_STRATEGY) {
                IRebaseStrategy(vault).checkInputData(array[i]);
            } else if (mode == Constants.EXIT_STRATEGY) {
                IExitStrategy(vault).checkInputData(array[i]);
            } else if (mode == Constants.LIQUIDITY_DISTRIBUTION) {
                ILiquidityDistributionStrategy(vault).checkInputData(array[i]);
            }
        }
    }

    /// @inheritdoc ICLTModules
    function validateModes(
        ICLTBase.PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee
    )
        external
        override
    {
        if (managementFee > Constants.MAX_MANAGEMENT_FEE) revert IGovernanceFeeHandler.ManagementFeeLimitExceed();

        if (performanceFee > Constants.MAX_PERFORMANCE_FEE) revert IGovernanceFeeHandler.PerformanceFeeLimitExceed();

        if (actions.mode < 1 || actions.mode > 4) revert InvalidMode();

        if (actions.exitStrategy.length > 0) {
            _checkModeIds(Constants.EXIT_STRATEGY, actions.exitStrategy);
            _validateInputData(Constants.EXIT_STRATEGY, actions.exitStrategy);
        }

        if (actions.rebaseStrategy.length > 0) {
            _checkModeIds(Constants.REBASE_STRATEGY, actions.rebaseStrategy);
            _validateInputData(Constants.REBASE_STRATEGY, actions.rebaseStrategy);
        }

        if (actions.liquidityDistribution.length > 0) {
            _checkModeIds(Constants.LIQUIDITY_DISTRIBUTION, actions.liquidityDistribution);
            _validateInputData(Constants.LIQUIDITY_DISTRIBUTION, actions.liquidityDistribution);
        }
    }

    /// @dev Common checks for valid inputs.
    function _checkModeIds(bytes32 mode, ICLTBase.StrategyPayload[] memory array) private view {
        for (uint256 i = 0; i < array.length; i++) {
            if (!modulesActions[mode][array[i].actionName]) revert InvalidStrategyAction();
        }
    }

    /// @dev Common checks for valid inputs.
    function _checkModuleKey(bytes32 moduleKey) private pure {
        require(
            moduleKey == Constants.MODE || moduleKey == Constants.REBASE_STRATEGY
                || moduleKey == Constants.EXIT_STRATEGY || moduleKey == Constants.LIQUIDITY_DISTRIBUTION,
            "Invalid Strategy Key"
        );
    }
}
