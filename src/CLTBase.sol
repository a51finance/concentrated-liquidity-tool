// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase, IUniswapV3Pool } from "./interfaces/ICLTBase.sol";
import { ICLTModules } from "./interfaces/ICLTModules.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

import { CLTPayments } from "./base/CLTPayments.sol";
import { AccessControl } from "./base/AccessControl.sol";

import { Position } from "./libraries/Position.sol";
import { Constants } from "./libraries/Constants.sol";
import { PoolActions } from "./libraries/PoolActions.sol";
import { UserPositions } from "./libraries/UserPositions.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";
import { LiquidityShares } from "./libraries/LiquidityShares.sol";
import { StrategyFeeShares } from "./libraries/StrategyFeeShares.sol";

import { ERC721 } from "@solmate/tokens/ERC721.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import { IERC20Minimal } from "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";

import { LDFLibrary } from "./libraries/LDFLibrary.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "forge-std/console.sol";

/// @title A51 Finance Autonomus Liquidity Provision Base Contract
/// @author 0xMudassir
/// @notice The A51 ALP Base facilitates the liquidity strategies on concentrated AMM with dynamic adjustments based on
/// user preferences with the help of basic and advance liquidity modes
/// Holds the state for all strategies and it's users
contract CLTBase is ICLTBase, AccessControl, CLTPayments, ERC721 {
    using Position for StrategyData;
    using UserPositions for UserPositions.Data;

    using LDFLibrary for uint256[];
    using LDFLibrary for int24[];

    uint256 private _sharesId = 1;

    uint256 private _strategyId = 1;

    /// @notice The address of modes managment of strategy
    address public immutable cltModules;

    /// @notice The address of fee managment of strategy
    address public immutable feeHandler;

    /// @inheritdoc ICLTBase
    mapping(bytes32 => StrategyData) public override strategies;

    /// @inheritdoc ICLTBase
    mapping(uint256 => UserPositions.Data) public override positions;

    /// @notice The global fee growth as of last action on individual liquidity position in pool
    /// @dev The uncollected fee earned by individual position is first collected by global account and then distributed
    /// among the strategies having same ticks as of global account ticks according to the strategy fee growth & share
    mapping(bytes32 => StrategyFeeShares.GlobalAccount) private strategyGlobalFees;

    uint256[] public ldfWeights; // Weights for each tick
    int24[] public tickIndices; // List of ticks
    uint256 public totalWeight;

    event A(int24 tl, int24 tu, uint256 am0, uint256 am1);
    event B(int24 tl, int24 tu, uint256 am0, uint256 am1);
    event C(int24 tl, int24 tu, uint256 am0, uint256 am1);

    modifier isAuthorizedForToken(uint256 tokenId) {
        _authorization(tokenId);
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _weth9,
        address _feeHandler,
        address _cltModules,
        IUniswapV3Factory _factory
    )
        AccessControl(_owner)
        ERC721(_name, _symbol)
        CLTPayments(_factory, _weth9)
    {
        cltModules = _cltModules;
        feeHandler = _feeHandler;
    }

    /// @inheritdoc ICLTBase
    function createStrategy(
        StrategyKey calldata key,
        PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee,
        bool isCompound,
        bool isPrivate
    )
        external
        payable
        override
    {
        _validateModes(actions, managementFee, performanceFee);

        bytes memory positionActionsHash = abi.encode(actions);
        bytes32 strategyID = keccak256(abi.encode(_msgSender(), _strategyId++));

        strategies[strategyID] = StrategyData({
            key: key,
            owner: _msgSender(),
            actions: positionActionsHash,
            actionStatus: "",
            isCompound: isCompound,
            isPrivate: isPrivate,
            managementFee: managementFee,
            performanceFee: performanceFee,
            account: Account({
                fee0: 0,
                fee1: 0,
                balance0: 0,
                balance1: 0,
                totalShares: 0,
                uniswapLiquidity: 0,
                feeGrowthInside0LastX128: 0,
                feeGrowthInside1LastX128: 0,
                feeGrowthOutside0LastX128: 0,
                feeGrowthOutside1LastX128: 0
            })
        });

        (, uint256 strategyCreationFeeAmount,,) = _getGovernanceFee(isPrivate);

        if (strategyCreationFeeAmount > 0) TransferHelper.safeTransferETH(owner, strategyCreationFeeAmount);

        refundETH();

        emit StrategyCreated(strategyID);
    }

    // Initialize ticks and weights
    function initializeTicksAndWeights(IUniswapV3Pool pool, int24 tickSpread, uint8 distributionType) external {
        require(tickIndices.length == 0, "Already initialized");

        (, int24 tick,,,,,) = pool.slot0();

        (tickIndices, ldfWeights, totalWeight) =
            LDFLibrary.computeLDFWeights(tick, tickSpread, distributionType, pool.tickSpacing());
    }

    /// @inheritdoc ICLTBase
    function deposit(DepositParams calldata params)
        external
        payable
        override
        nonReentrancy
        whenNotPaused
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
        _authorizationOfStrategy(params.strategyId);

        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) = _deposit(
            params.strategyId, params.amount0Desired, params.amount1Desired, params.amount0Min, params.amount1Min
        );

        _mint(params.recipient, (tokenId = _sharesId++));

        positions[tokenId] = UserPositions.Data({
            strategyId: params.strategyId,
            liquidityShare: share,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        emit Deposit(tokenId, params.recipient, share, amount0, amount1);
    }

    /// @inheritdoc ICLTBase
    function updatePositionLiquidity(UpdatePositionParams calldata params)
        external
        payable
        override
        nonReentrancy
        whenNotPaused
        returns (uint256 share, uint256 amount0, uint256 amount1)
    {
        UserPositions.Data storage position = positions[params.tokenId];
        bytes32 strategyId = position.strategyId;

        _authorizationOfStrategy(strategyId);

        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) =
            _deposit(strategyId, params.amount0Desired, params.amount1Desired, params.amount0Min, params.amount1Min);

        if (!strategies[strategyId].isCompound) {
            position.updateUserPosition(feeGrowthInside0LastX128, feeGrowthInside1LastX128);
        }

        position.liquidityShare += share;

        emit PositionUpdated(params.tokenId, share, amount0, amount1);
    }

    /// @inheritdoc ICLTBase
    function withdraw(WithdrawParams calldata params)
        external
        override
        nonReentrancy
        isAuthorizedForToken(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        UserPositions.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        StrategyFeeShares.GlobalAccount storage global = _updateGlobals(strategy, position.strategyId);

        if (params.liquidity == 0) revert InvalidShare();
        if (position.liquidityShare == 0) revert NoLiquidity();
        if (position.liquidityShare < params.liquidity) revert InvalidShare();

        // these vars used for multipurpose || strategist fee & contract balance
        Account memory vars;

        (vars.uniswapLiquidity, amount0, amount1,,) = PoolActions.burnUserLiquidity(
            strategy.key,
            strategy.account.uniswapLiquidity,
            FullMath.mulDiv(params.liquidity, 1e18, strategy.account.totalShares)
        );

        if (!strategy.isCompound) {
            (vars.fee0, vars.fee1) = position.claimFeeForNonCompounders(strategy);
        } else {
            (vars.fee0, vars.fee1) = position.claimFeeForCompounders(strategy);
        }

        // deduct any fees if required for strategist
        IGovernanceFeeHandler.ProtocolFeeRegistry memory protocolFee;

        (,, protocolFee.protcolFeeOnManagement, protocolFee.protcolFeeOnPerformance) =
            _getGovernanceFee(strategy.isPrivate);

        (vars.balance0, vars.balance1) = transferFee(
            strategy.key,
            protocolFee.protcolFeeOnPerformance,
            strategy.performanceFee,
            vars.fee0,
            vars.fee1,
            owner,
            strategy.owner
        );

        vars.fee0 -= vars.balance0;
        vars.fee1 -= vars.balance1;

        (vars.balance0, vars.balance1) = transferFee(
            strategy.key,
            protocolFee.protcolFeeOnManagement,
            strategy.managementFee,
            amount0,
            amount1,
            owner,
            strategy.owner
        );

        amount0 -= vars.balance0;
        amount1 -= vars.balance1;

        // should calculate correct amounts for both compounders & non-compounders
        uint256 userShare0 = FullMath.mulDiv(strategy.account.balance0, params.liquidity, strategy.account.totalShares);
        uint256 userShare1 = FullMath.mulDiv(strategy.account.balance1, params.liquidity, strategy.account.totalShares);

        amount0 += userShare0 + vars.fee0;
        amount1 += userShare1 + vars.fee1;

        strategy.account.balance0 -= userShare0;
        strategy.account.balance1 -= userShare1;

        if (!strategy.isCompound) {
            position.tokensOwed0 = 0;
            position.tokensOwed1 = 0;
        }

        if (amount0 < params.amount0Min || amount1 < params.amount1Min) revert MinimumAmountsExceeded();

        if (amount0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), amount0);
        }

        if (amount1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), amount1);
        }

        if (strategy.getHodlStatus() == false) global.totalLiquidity -= params.liquidity;

        position.liquidityShare -= params.liquidity;
        strategy.account.totalShares -= params.liquidity;
        strategy.account.uniswapLiquidity -= vars.uniswapLiquidity;

        emit Withdraw(params.tokenId, params.recipient, params.liquidity, amount0, amount1, vars.fee0, vars.fee1);
    }

    /// @inheritdoc ICLTBase
    function claimPositionFee(ClaimFeesParams calldata params)
        external
        override
        nonReentrancy
        whenNotPaused
        isAuthorizedForToken(params.tokenId)
    {
        UserPositions.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        _updateGlobals(strategy, position.strategyId);

        if (strategy.isCompound) revert onlyNonCompounders();
        if (position.liquidityShare == 0) revert NoLiquidity();

        (uint128 tokensOwed0, uint128 tokensOwed1) = position.claimFeeForNonCompounders(strategy);

        (,,, uint256 protcolFeeOnPerformance) = _getGovernanceFee(strategy.isPrivate);

        (uint256 fee0, uint256 fee1) = transferFee(
            strategy.key,
            protcolFeeOnPerformance,
            strategy.performanceFee,
            tokensOwed0,
            tokensOwed1,
            owner,
            strategy.owner
        );

        if (tokensOwed0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), tokensOwed0 - fee0);
        }

        if (tokensOwed1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), tokensOwed1 - fee1);
        }

        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        emit Collect(params.tokenId, params.recipient, tokensOwed0 - fee0, tokensOwed1 - fee1);
    }

    /// @inheritdoc ICLTBase
    function shiftLiquidity(ShiftLiquidityParams calldata params) external override onlyOperator {
        StrategyData storage strategy = strategies[params.strategyId];
        StrategyFeeShares.GlobalAccount storage global = _updateGlobals(strategy, params.strategyId);

        Account memory vars;

        vars.uniswapLiquidity = strategy.account.uniswapLiquidity;

        // only burn this strategy liquidity not other strategy with same ticks
        (vars.balance0, vars.balance1,,) = PoolActions.burnLiquidity(strategy.key, vars.uniswapLiquidity);

        // global liquidity will be less if strategy has activated exit mode
        if (strategy.getHodlStatus() == false) {
            global.totalLiquidity -= strategy.account.totalShares;
        }

        // returns protocol fees
        (uint256 automationFee,,,) = _getGovernanceFee(strategy.isPrivate);

        // deduct any fees if required for protocol
        (vars.fee0, vars.fee1) =
            transferFee(strategy.key, 0, automationFee, vars.balance0, vars.balance1, address(0), owner);

        vars.balance0 -= vars.fee0;
        vars.balance1 -= vars.fee1;

        if (strategy.isCompound) {
            vars.balance0 += strategy.account.fee0;
            vars.balance1 += strategy.account.fee1;
            emit FeeCompounded(params.strategyId, strategy.account.fee0, strategy.account.fee1);
        }

        // add unused assets for new liquidity
        vars.balance0 += strategy.account.balance0;
        vars.balance1 += strategy.account.balance1;

        if (params.swapAmount != 0) {
            (int256 amount0Swapped, int256 amount1Swapped) =
                PoolActions.swapToken(params.key.pool, params.zeroForOne, params.swapAmount, params.sqrtPriceLimitX96);

            (vars.balance0, vars.balance1) = PoolActions.amountsDirection(
                params.zeroForOne,
                vars.balance0,
                vars.balance1,
                uint256(amount0Swapped < 0 ? -amount0Swapped : amount0Swapped),
                uint256(amount1Swapped < 0 ? -amount1Swapped : amount1Swapped)
            );
        }

        uint128 liquidityDelta;
        uint256 amount0Added;
        uint256 amount1Added;

        if (params.shouldMint) {
            (liquidityDelta, amount0Added, amount1Added) =
                PoolActions.mintLiquidity(params.key, vars.balance0, vars.balance1);
        }

        // update state { this state will be reflected to all users having this strategyID }
        strategy.updateStrategy(
            strategyGlobalFees,
            params.key,
            params.moduleStatus,
            liquidityDelta,
            vars.balance0 - amount0Added,
            vars.balance1 - amount1Added
        );

        emit LiquidityShifted(params.strategyId, params.shouldMint, params.zeroForOne, params.swapAmount);
    }

    function redistributeLiquidity(bytes32 strategyId, int24 tickSpread, uint8 distributionType) external {
        StrategyData storage strategy = strategies[strategyId];
        StrategyFeeShares.GlobalAccount storage global = _updateGlobals(strategy, strategyId);

        Account memory vars;

        (vars.balance0, vars.balance1,,) = PoolActions.burnLiquidity(strategy.key, strategy.account.uniswapLiquidity);

        vars.balance0 += strategy.account.fee0 + strategy.account.balance0;
        vars.balance1 += strategy.account.fee1 + strategy.account.balance1;

        // Step 2: Compute target asset ratio using CAF
        (uint256 targetAmount0, uint256 targetAmount1) =
            computeTargetRatio(strategy.key.pool, vars.balance0 + vars.balance1);

        console.log("target -> ", targetAmount0, targetAmount1);

        (, int24 centralTick,,,,,) = strategy.key.pool.slot0();

        // // Step 3: Perform swaps to rebalance asset ratios
        (int256 amount0Swapped, int256 amount1Swapped, bool zeroForOne) =
            rebalanceUsingICAF(strategy.key.pool, vars.balance0, vars.balance1, targetAmount0, targetAmount1);

        (vars.balance0, vars.balance1) = PoolActions.amountsDirection(
            zeroForOne,
            vars.balance0,
            vars.balance1,
            uint256(amount0Swapped < 0 ? -amount0Swapped : amount0Swapped),
            uint256(amount1Swapped < 0 ? -amount1Swapped : amount1Swapped)
        );

        // Step 4: Compute new weights and ticks
        (tickIndices, ldfWeights, totalWeight) =
            LDFLibrary.computeLDFWeights(centralTick, tickSpread, distributionType, strategy.key.pool.tickSpacing());

        // uint256 liquidityAmount0;
        // uint256 liquidityAmount1;
        int24 tickLower;
        int24 tickUpper;

        console.log("after swap ", vars.balance0, vars.balance1);

        console.log("length 0> ", tickIndices.length, ldfWeights.length);

        // Step 5: Re-add liquidity based on updated balances and weights
        for (uint256 i = 0; i < tickIndices.length; i++) {
            // liquidityAmount0 = (ldfWeights[i] * vars.balance0) / 1e18;
            // liquidityAmount1 = (ldfWeights[i] * vars.balance1) / 1e18;

            tickLower = PoolActions.floor(tickIndices[i], 10);
            tickUpper = PoolActions.floor((i < tickIndices.length - 1) ? tickIndices[i + 1] : tickLower + 10, 10);

            console.log(
                "reserves -> ",
                ldfWeights[i],
                (ldfWeights[i] * vars.balance0) / 1e18,
                (ldfWeights[i] * vars.balance1) / 1e18
            );

            console.logInt(tickLower);
            console.logInt(tickUpper);

            (, targetAmount0, targetAmount1) = PoolActions.mintLiquidity(
                ICLTBase.StrategyKey({ pool: strategy.key.pool, tickLower: tickLower, tickUpper: tickUpper }),
                (ldfWeights[i] * vars.balance0) / 1e18,
                (ldfWeights[i] * vars.balance1) / 1e18
            );

            emit A(tickLower, tickUpper, targetAmount0, targetAmount1);
        }

        console.log(
            "before last position balance -> ",
            IERC20Minimal(0x2e234DAe75C793f67A35089C9d99245E1C58470b).balanceOf(address(this)),
            IERC20Minimal(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f).balanceOf(address(this))
        );

        tickLower = centralTick - tickSpread - (tickSpread * 2); // Left end of carpet range
        tickUpper = centralTick + tickSpread + (tickSpread * 2); // Right end of carpet range

        (, targetAmount0, targetAmount1) = PoolActions.mintLiquidity(
            ICLTBase.StrategyKey({
                pool: strategy.key.pool,
                tickLower: PoolActions.floor(tickLower, 10),
                tickUpper: PoolActions.floor(tickUpper, 10)
            }),
            IERC20Minimal(0x2e234DAe75C793f67A35089C9d99245E1C58470b).balanceOf(address(this)),
            IERC20Minimal(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f).balanceOf(address(this))
        );

        console.log(
            "after last position balance -> ",
            IERC20Minimal(0x2e234DAe75C793f67A35089C9d99245E1C58470b).balanceOf(address(this)),
            IERC20Minimal(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f).balanceOf(address(this))
        );
    }

    function computeTargetRatio(
        IUniswapV3Pool pool,
        uint256 totalBalance
    )
        internal
        view
        returns (uint256 targetAmount0, uint256 targetAmount1)
    {
        uint256 cumulativeWeight0 =
            tickIndices.caf(ldfWeights, tickIndices[0], tickIndices[tickIndices.length - 1], pool.tickSpacing());

        targetAmount0 = (cumulativeWeight0 * totalBalance) / (cumulativeWeight0 + cumulativeWeight0);
        targetAmount1 = totalBalance - targetAmount0;
    }

    function rebalanceUsingICAF(
        IUniswapV3Pool pool,
        uint256 currentBalance0,
        uint256 currentBalance1,
        uint256 targetAmount0,
        uint256 targetAmount1
    )
        internal
        returns (int256 amount0Swapped, int256 amount1Swapped, bool zeroForOne)
    {
        if (currentBalance0 > targetAmount0) {
            uint256 excessToken0 = currentBalance0 - targetAmount0;
            int24 targetTick = tickIndices.icaf(ldfWeights, targetAmount0 / totalWeight);

            zeroForOne = true;

            (amount0Swapped, amount1Swapped) =
                PoolActions.swapToken(pool, zeroForOne, int256(excessToken0), TickMath.MIN_SQRT_RATIO + 1);
        } else if (currentBalance1 > targetAmount1) {
            uint256 excessToken1 = currentBalance1 - targetAmount1;
            int24 targetTick = tickIndices.icaf(ldfWeights, targetAmount1 / totalWeight);

            zeroForOne = false;

            (amount0Swapped, amount1Swapped) =
                PoolActions.swapToken(pool, zeroForOne, int256(excessToken1), TickMath.MAX_SQRT_RATIO - 1);
        }
    }

    /// @notice updates the info of strategy
    /// @dev The strategy can be update only by owner
    function updateStrategyBase(
        bytes32 strategyId,
        address owner,
        uint256 managementFee,
        uint256 performanceFee,
        PositionActions calldata actions
    )
        external
    {
        _validateModes(actions, managementFee, performanceFee);

        StrategyData storage strategy = strategies[strategyId];
        if (strategy.owner != _msgSender()) revert InvalidCaller();
        if (owner == address(0)) revert OwnerCannotBeZeroAddress();

        strategy.updateStrategyState(owner, managementFee, performanceFee, abi.encode(actions));

        emit StrategyUpdated(strategyId);
    }

    function _deposit(
        bytes32 strategyId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    )
        private
        returns (
            uint256 share,
            uint256 amount0,
            uint256 amount1,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128
        )
    {
        StrategyData storage strategy = strategies[strategyId];
        StrategyFeeShares.GlobalAccount storage global = _updateGlobals(strategy, strategyId);

        Account memory vars;

        bool isExit = strategy.getHodlStatus();

        // prevent user drains others
        if (strategy.isCompound && isExit == false) {
            (vars.uniswapLiquidity, vars.balance0, vars.balance1) = PoolActions.compoundFees(
                strategy.key,
                strategy.account.balance0 + strategy.account.fee0,
                strategy.account.balance1 + strategy.account.fee1
            );

            if (vars.uniswapLiquidity > 0) {
                strategy.updateForCompound(vars.uniswapLiquidity, vars.balance0, vars.balance1);
                emit FeeCompounded(strategyId, vars.balance0, vars.balance1);
            }
        }

        // shares should not include fee for non-compounders
        (share, amount0, amount1) = LiquidityShares.computeLiquidityShare(strategy, amount0Desired, amount1Desired);

        // liquidity frontrun checks here
        if (share == 0) revert InvalidShare();

        if (strategy.account.totalShares == 0) {
            if (share < Constants.MIN_INITIAL_SHARES) revert InvalidShare();
        }

        if (amount0 < amount0Min || amount1 < amount1Min) revert MinimumAmountsExceeded();

        pay(strategy.key.pool.token0(), _msgSender(), address(this), amount0);
        pay(strategy.key.pool.token1(), _msgSender(), address(this), amount1);

        // now contract balance has: new user asset + previous user unused assets + collected fee of strategy
        if (isExit == false) {
            (vars.uniswapLiquidity, vars.balance0, vars.balance1) =
                PoolActions.mintLiquidity(strategy.key, amount0, amount1);
        }

        strategy.update(global, vars.uniswapLiquidity, share, amount0, amount1, vars.balance0, vars.balance1);

        refundETH();

        feeGrowthInside0LastX128 = strategy.account.feeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = strategy.account.feeGrowthInside1LastX128;
    }

    /// @notice Returns maximum amount of fees owed to a specific user position
    /// @param tokenId The ID of the Unpilot NFT for which tokens will be collected
    /// @return fee0 Amount of fees in token0
    /// @return fee1 Amount of fees in token1
    function getUserfee(uint256 tokenId) external returns (uint256 fee0, uint256 fee1) {
        UserPositions.Data storage position = positions[tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        _updateGlobals(strategy, position.strategyId);

        (fee0, fee1) = position.claimFeeForNonCompounders(strategy);
    }

    /// @dev Collects liquidity position fee and update global fee growth so earned fees are
    /// updated. Should be called if total amounts needs to include up-to-date fees
    function _updateGlobals(
        StrategyData storage strategy,
        bytes32 strategyId
    )
        private
        returns (StrategyFeeShares.GlobalAccount storage global)
    {
        global = StrategyFeeShares.updateGlobalStrategyFees(strategyGlobalFees, strategy.key);
        (uint256 earned0, uint256 earned1) = StrategyFeeShares.updateStrategyFees(strategy, global);

        emit StrategyFee(strategyId, earned0, earned1);
    }

    /// @notice Returns the liquidity and fee earned by A51 strategy.
    /// @param strategyId Hash of strategy ID
    /// @return liquidity The currently liquidity available to the pool by strategy
    /// @return fee0 The computed amount of token0 owed to the strategy as of the global update
    /// @return fee1 The computed amount of token1 owed to the strategy as of the global update
    function getStrategyReserves(bytes32 strategyId) external returns (uint128 liquidity, uint256 fee0, uint256 fee1) {
        StrategyData storage strategy = strategies[strategyId];

        _updateGlobals(strategy, strategyId);

        (liquidity, fee0, fee1) = (strategy.account.uniswapLiquidity, strategy.account.fee0, strategy.account.fee1);
    }

    /// @notice Returns the protocol fee value
    /// @param isPrivate Bool value weather strategy is private or public
    function _getGovernanceFee(bool isPrivate)
        private
        view
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        )
    {
        return IGovernanceFeeHandler(feeHandler).getGovernanceFee(isPrivate);
    }

    /// @dev Common checks for valid inputs.
    function _validateModes(PositionActions calldata actions, uint256 managementFee, uint256 performanceFee) private {
        ICLTModules(cltModules).validateModes(actions, managementFee, performanceFee);
    }

    function _authorization(uint256 tokenID) private view {
        require(ownerOf(tokenID) == _msgSender());
    }

    function _authorizationOfStrategy(bytes32 strategyId) private view {
        if (strategies[strategyId].isPrivate) {
            require(strategies[strategyId].owner == _msgSender());
        }
    }

    function tokenURI(uint256 id) public view override returns (string memory) { }
}
