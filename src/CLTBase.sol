// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "./interfaces/ICLTBase.sol";
import { IPreference } from "./interfaces/modules/IPreference.sol";
import { IExitStrategy } from "./interfaces/modules/IExitStrategy.sol";
import { ILiquidityDistribution } from "./interfaces/modules/ILiquidityDistribution.sol";

import { CLTPayments } from "./base/CLTPayments.sol";
import { AccessControl } from "./base/AccessControl.sol";

import { Position } from "./libraries/Position.sol";
import { Constants } from "./libraries/Constants.sol";
import { PoolActions } from "./libraries/PoolActions.sol";
import { FixedPoint128 } from "./libraries/FixedPoint128.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";
import { LiquidityShares } from "./libraries/LiquidityShares.sol";

import { ERC721 } from "@solmate/tokens/ERC721.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title A51 Finance Autonomus Liquidity Provision Base Contract
/// @author 0xMudassir
/// @notice The A51 ALP Base facilitates the liquidity strategies on concentrated AMM with dynamic adjustments based on
/// user preferences with the help of basic and advance liquidity modes
/// Holds the state for all strategies and it's users
contract CLTBase is ICLTBase, AccessControl, CLTPayments, ERC721 {
    using Position for StrategyData;

    uint256 private _nextId = 1;

    uint256 public protocolFee;

    /// @inheritdoc ICLTBase
    mapping(uint256 => Position.Data) public override positions;

    /// @inheritdoc ICLTBase
    mapping(bytes32 => StrategyData) public override strategies;

    mapping(bytes32 => StrategyFees) public strategyFees;

    mapping(bytes32 => address) public modeVaults;

    mapping(bytes32 => mapping(bytes32 => bool)) public modulesActions;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender);
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _weth9,
        uint256 _protocolFee,
        IUniswapV3Factory _factory
    )
        AccessControl(_owner)
        ERC721(_name, _symbol)
        CLTPayments(_factory, _weth9)
    {
        protocolFee = _protocolFee;
    }

    /// @inheritdoc ICLTBase
    function createStrategy(
        StrategyKey calldata key,
        PositionActions calldata actions,
        uint256 strategistFee,
        bool isCompound
    )
        external
        override
    {
        if (actions.mode < 0 && actions.mode > 4) revert InvalidInput();

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

        bytes32 strategyID = keccak256(abi.encode(msg.sender, _nextId++));

        bytes memory positionActionsHash = abi.encode(actions);

        strategies[strategyID] = StrategyData({
            key: key,
            owner: msg.sender,
            actions: positionActionsHash,
            actionStatus: "",
            isCompound: isCompound,
            balance0: 0,
            balance1: 0,
            totalShares: 0,
            uniswapLiquidity: 0,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0
        });

        strategyFees[strategyID] = StrategyFees({ protocolFee: protocolFee, strategistFee: strategistFee });

        emit StrategyCreated(strategyID, positionActionsHash, key, isCompound);
    }

    /// @inheritdoc ICLTBase
    function deposit(DepositParams calldata params)
        external
        payable
        override
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
        StrategyData storage strategy = strategies[params.strategyId];
        if (!strategy.isCompound && strategy.totalShares > 0) strategy.updatePositionFee();

        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) =
            _deposit(params.strategyId, params.amount0Desired, params.amount1Desired);

        _mint(params.recipient, (tokenId = _nextId++));

        positions[tokenId] = Position.Data({
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
        override
        returns (uint256 share, uint256 amount0, uint256 amount1)
    {
        Position.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        if (!strategy.isCompound) strategy.updatePositionFee();

        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) =
            _deposit(position.strategyId, params.amount0Desired, params.amount1Desired);

        if (!strategies[position.strategyId].isCompound) {
            position.tokensOwed0 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                    position.liquidityShare,
                    FixedPoint128.Q128
                )
            );

            position.tokensOwed1 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                    position.liquidityShare,
                    FixedPoint128.Q128
                )
            );

            position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }

        position.liquidityShare += share;
    }

    /// @inheritdoc ICLTBase
    function withdraw(WithdrawParams calldata params)
        external
        override
        isAuthorizedForToken(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        Position.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        uint256 positionLiquidity = position.liquidityShare;

        if (positionLiquidity == 0) revert NoLiquidity();
        if (positionLiquidity < params.liquidity) revert InvalidShare();
        if (!strategy.isCompound) strategy.updatePositionFee();

        uint256 fees0;
        uint256 fees1;

        (amount0, amount1, fees0, fees1) = PoolActions.burnUserLiquidity(
            strategy.key,
            strategy.uniswapLiquidity,
            strategy.isCompound ? FullMath.mulDiv(params.liquidity, 1e18, strategy.totalShares) : params.liquidity,
            strategy.isCompound
        );

        if (!strategy.isCompound) {
            amount0 += uint128(position.tokensOwed0)
                + uint128(
                    FullMath.mulDiv(
                        strategy.feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                        positionLiquidity,
                        FixedPoint128.Q128
                    )
                );

            amount1 += uint128(position.tokensOwed1)
                + uint128(
                    FullMath.mulDiv(
                        strategy.feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                        positionLiquidity,
                        FixedPoint128.Q128
                    )
                );

            position.tokensOwed0 = 0;
            position.tokensOwed1 = 0;

            position.feeGrowthInside0LastX128 = strategy.feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = strategy.feeGrowthInside1LastX128;
        }

        uint256 balance0 = strategy.balance0 + fees0;
        uint256 balance1 = strategy.balance1 + fees1;

        uint256 userShare0 = FullMath.mulDiv(balance0, params.liquidity, strategy.totalShares);
        uint256 userShare1 = FullMath.mulDiv(balance1, params.liquidity, strategy.totalShares);

        amount0 += userShare0;
        amount1 += userShare1;

        if (amount0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), amount0);
        }

        if (amount1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), amount1);
        }

        balance0 -= userShare0;
        balance1 -= userShare1;

        emit Withdraw(params.tokenId, params.recipient, params.liquidity, amount0, amount1);

        // mint liquidity here for compounders with balances || reuse userShare vars
        if (strategy.isCompound) {
            /// if opposite assets left?
            (, userShare0, userShare1) = PoolActions.mintLiquidity(strategy.key, balance0, balance1);
        }

        // recheck for both scenerios
        // ✔ mint additional fees for compounders
        // ✔ update state.balance[0, 1] again after compounding fee from balance and collected fee
        // ✔ update feeGrowth for non compounders
        strategy.balance0 = balance0 - userShare0;
        strategy.balance1 = balance1 - userShare1;
        position.liquidityShare = positionLiquidity - params.liquidity;
    }

    /// @inheritdoc ICLTBase
    function claimPositionFee(ClaimFeesParams calldata params) external override isAuthorizedForToken(params.tokenId) {
        Position.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        if (strategy.isCompound) revert onlyNonCompounders();
        if (position.liquidityShare == 0) revert NoLiquidity();

        strategy.updatePositionFee();

        (uint128 tokensOwed0, uint128 tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);

        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            (strategy.feeGrowthInside0LastX128, strategy.feeGrowthInside1LastX128);

        tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                position.liquidityShare,
                FixedPoint128.Q128
            )
        );

        tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                position.liquidityShare,
                FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;

        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        if (tokensOwed0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), tokensOwed0);
        }

        if (tokensOwed1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), tokensOwed1);
        }

        emit Collect(params.tokenId, params.recipient, tokensOwed0, tokensOwed1);
    }

    /// @inheritdoc ICLTBase
    function shiftLiquidity(ShiftLiquidityParams calldata params) external override onlyOperator {
        // checks
        PoolActions.checkRange(params.key.tickLower, params.key.tickUpper, params.key.pool.tickSpacing());

        StrategyData storage strategy = strategies[params.strategyId];

        if (!strategy.isCompound) strategy.updatePositionFee();

        uint128 liquidity;
        uint256 amount0Added;
        uint256 amount1Added;

        // only burn this strategy liquidity not others
        (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) =
            PoolActions.burnLiquidity(strategy.key, strategy.uniswapLiquidity);

        // deduct any fees if required for protocol & strategist
        (amount0Added, amount1Added) =
            transferFee(strategy.key, strategyFees[params.strategyId].protocolFee, amount0, amount1, owner);

        amount0 -= amount0Added;
        amount1 -= amount1Added;

        (amount0Added, amount1Added) =
            transferFee(strategy.key, strategyFees[params.strategyId].strategistFee, fees0, fees0, strategy.owner);

        fees0 -= amount0Added;
        fees1 -= amount1Added;

        if (strategy.isCompound) {
            amount0 += fees0 + strategy.balance0;
            amount1 += fees1 + strategy.balance1;
        }

        if (params.swapAmount != 0) {
            (int256 amount0Swapped, int256 amount1Swapped) =
                PoolActions.swapToken(params.key.pool, params.zeroForOne, params.swapAmount);

            (amount0, amount1) = PoolActions.amountsDirection(
                params.zeroForOne, amount0, amount1, uint256(amount0Swapped), uint256(amount1Swapped)
            );
        }

        /// reuse amountAdded vars
        if (params.shouldMint) {
            (liquidity, amount0Added, amount1Added) = PoolActions.mintLiquidity(params.key, amount0, amount1);
        }

        // update state { this state will be reflected to all users having this strategyID }
        strategy.updateStrategy(
            params.key, params.moduleStatus, liquidity, amount0 - amount0Added, amount1 - amount1Added
        );
    }

    function updateStrategyBase(NewState calldata state) external {
        StrategyData storage strategy = strategies[state.strategyId];
        if (strategy.owner != msg.sender) revert InvalidCaller();

        /// should we remove previous actions state?
        strategy.updateStrategyState(state.newKey, state.newActions);
    }

    function setProtocolFee(bytes32 strategyID, uint256 value) external onlyOperator {
        if (value >= Constants.MAX_PROTOCOL_FEE) revert InvalidInput();

        if (strategyID == 0) {
            emit ProtocolFeeOverallUpdated(protocolFee = value);
        } else {
            emit ProtocolFeeStrategyUpdated(strategyFees[strategyID].protocolFee = value);
        }
    }

    /// @notice Whitlist new ids for advance strategy modes & updates the address of mode's vault
    /// @dev New id can only be added for only rebase, exit & liquidity advance modes
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param modeVault New address of mode's vault
    /// @param newModule Array of new mode ids to be added against advance modes
    function addModule(
        bytes32 moduleKey,
        bytes32 newModule,
        address modeVault,
        bool isActivated
    )
        external
        onlyOperator
    {
        if (
            moduleKey == Constants.MODE || moduleKey == Constants.REBASE_STRATEGY
                || moduleKey == Constants.EXIT_STRATEGY || moduleKey == Constants.LIQUIDITY_DISTRIBUTION
        ) {
            modeVaults[moduleKey] = modeVault;
            modulesActions[moduleKey][newModule] = isActivated;
        } else {
            revert InvalidModule(moduleKey);
        }
    }

    function tokenURI(uint256 id) public view override returns (string memory) { }

    function _deposit(
        bytes32 strategyId,
        uint256 amount0Desired,
        uint256 amount1Desired
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

        (share, amount0, amount1) = LiquidityShares.computeLiquidityShare(
            strategy.key,
            strategy.isCompound,
            strategy.uniswapLiquidity,
            amount0Desired,
            amount1Desired,
            strategy.balance0,
            strategy.balance1,
            strategy.totalShares
        );

        // liquidity frontrun checks here
        if (share == 0) revert InvalidShare();

        if (strategy.totalShares == 0) {
            if (share < Constants.MIN_INITIAL_SHARES) revert InvalidShare();
        }

        pay(strategy.key.pool.token0(), msg.sender, address(this), amount0);
        pay(strategy.key.pool.token1(), msg.sender, address(this), amount1);

        // bug we need to track the liquidity amounts of all users in a single strategy & that value will be used in
        // shifting of liquidity for each strategy
        // ideally in child pattern there's only one position for that contract at a time
        // (TL, TU, Owner) => total uniswapLiquidity added by the contract
        // but here multiple positions could be open at a time for same ticks so if we do
        // (TL, TU, Owner) => uniswapLiquidity: it will pull all other strategies liquidity which is having the same
        // ticks that are not meant to be pulled.
        (uint128 liquidityAdded, uint256 amount0Added, uint256 amount1Added) =
            PoolActions.mintLiquidity(strategy.key, amount0, amount1);

        strategy.update(liquidityAdded, share, amount0, amount1, amount0Added, amount1Added);

        feeGrowthInside0LastX128 = strategy.feeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = strategy.feeGrowthInside1LastX128;
    }

    /// @notice Validates the strategy encoded input data
    function _validateInputData(bytes32 mode, StrategyPayload[] memory array) private {
        address vault = modeVaults[mode];

        for (uint256 i = 0; i < array.length; i++) {
            if (mode == Constants.REBASE_STRATEGY) {
                IPreference(vault).checkInputData(array[i]);
            }

            if (mode == Constants.EXIT_STRATEGY) {
                IExitStrategy(vault).checkInputData(array[i]);
            }

            if (mode == Constants.LIQUIDITY_DISTRIBUTION) {
                ILiquidityDistribution(vault).checkInputData(array[i]);
            } else {
                revert InvalidModule(mode);
            }
        }
    }

    function _checkModeIds(bytes32 mode, StrategyPayload[] memory array) private view {
        for (uint256 i = 0; i < array.length; i++) {
            if (!modulesActions[mode][array[i].actionName]) revert InvalidModule(array[i].actionName);
        }
    }
}
