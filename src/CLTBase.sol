// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "./interfaces/ICLTBase.sol";
import { ICLTModules } from "./interfaces/ICLTModules.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

import { CLTPayments } from "./base/CLTPayments.sol";
import { AccessControl } from "./base/AccessControl.sol";

import { Position } from "./libraries/Position.sol";
import { Constants } from "./libraries/Constants.sol";
import { PoolActions } from "./libraries/PoolActions.sol";
import { FixedPoint128 } from "./libraries/FixedPoint128.sol";
import { UserPositions } from "./libraries/UserPositions.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";
import { LiquidityShares } from "./libraries/LiquidityShares.sol";
import { StrategyFeeShares } from "./libraries/StrategyFeeShares.sol";

import { ERC721 } from "@solmate/tokens/ERC721.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title A51 Finance Autonomus Liquidity Provision Base Contract
/// @author 0xMudassir
/// @notice The A51 ALP Base facilitates the liquidity strategies on concentrated AMM with dynamic adjustments based on
/// user preferences with the help of basic and advance liquidity modes
/// Holds the state for all strategies and it's users
contract CLTBase is ICLTBase, AccessControl, CLTPayments, Context, ERC721 {
    using Position for StrategyData;
    using UserPositions for UserPositions.Data;
    using StrategyFeeShares for StrategyFeeShares.GlobalAccount;

    uint256 private _sharesId = 1;

    uint256 private _strategyId = 1;

    address public immutable cltModules;

    address public immutable feeHandler;

    mapping(bytes32 => StrategyFeeShares.StrategyAccount) private strategyFees;

    mapping(bytes32 => StrategyFeeShares.GlobalAccount) private strategyGlobalFees;

    /// @inheritdoc ICLTBase
    mapping(bytes32 => StrategyData) public override strategies;

    /// @inheritdoc ICLTBase
    mapping(uint256 => UserPositions.Data) public override positions;

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
                feeGrowthInside1LastX128: 0
            })
        });

        (uint256 strategyCreationFeeAmount,,,) = _getGovernanceFee(isPrivate);

        if (strategyCreationFeeAmount > 0) TransferHelper.safeTransferETH(owner, strategyCreationFeeAmount);

        emit StrategyCreated(strategyID);
    }

    /// @inheritdoc ICLTBase
    function deposit(DepositParams calldata params)
        external
        payable
        override
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
        _authorizationOfStrategy(params.strategyId);

        StrategyData storage strategy = strategies[params.strategyId];
        if (!strategy.isCompound && strategy.account.totalShares > 0) strategy.updatePositionFee();
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) =
            _deposit(params.strategyId, params.amount0Desired, params.amount1Desired);

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
        override
        returns (uint256 share, uint256 amount0, uint256 amount1)
    {
        UserPositions.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        _authorizationOfStrategy(position.strategyId);

        if (!strategy.isCompound) strategy.updatePositionFee();

        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) =
            _deposit(position.strategyId, params.amount0Desired, params.amount1Desired);

        if (!strategies[position.strategyId].isCompound) {
            position.updateUserPosition(feeGrowthInside0LastX128, feeGrowthInside1LastX128);
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
        UserPositions.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        if (position.liquidityShare == 0) revert NoLiquidity();
        if (position.liquidityShare < params.liquidity) revert InvalidShare();
        if (!strategy.isCompound) strategy.updatePositionFee();

        uint256 fees0;
        uint256 fees1;

        /// these vars used for multipurpose || strategist fee & contract balance
        uint256 balance0;
        uint256 balance1;
        uint128 liquidity;

        (liquidity, amount0, amount1, fees0, fees1) = PoolActions.burnUserLiquidity(
            strategy.key,
            strategy.account.uniswapLiquidity,
            strategy.isCompound
                ? FullMath.mulDiv(params.liquidity, 1e18, strategy.account.totalShares)
                : params.liquidity,
            strategy.isCompound
        );

        if (!strategy.isCompound) (fees0, fees1) = position.claimPositionAmounts(strategy);

        // deduct any fees if required for strategist
        IGovernanceFeeHandler.ProtocolFeeRegistry memory protocolFee;

        (,, protocolFee.protcolFeeOnManagement, protocolFee.protcolFeeOnPerformance) =
            _getGovernanceFee(strategy.isPrivate);

        (balance0, balance1) = transferFee(
            strategy.key,
            protocolFee.protcolFeeOnPerformance,
            strategy.performanceFee,
            fees0,
            fees0,
            owner,
            strategy.owner
        );

        fees0 -= balance0;
        fees1 -= balance1;

        (balance0, balance1) = transferFee(
            strategy.key,
            protocolFee.protcolFeeOnManagement,
            strategy.managementFee,
            amount0,
            amount1,
            owner,
            strategy.owner
        );

        amount0 -= balance0;
        amount1 -= balance1;

        if (!strategy.isCompound) {
            amount0 += fees0;
            amount1 += fees1;
        } else {
            balance0 = strategy.account.balance0 + fees0;
            balance1 = strategy.account.balance1 + fees1;

            uint256 userShare0 = FullMath.mulDiv(balance0, params.liquidity, strategy.account.totalShares);
            uint256 userShare1 = FullMath.mulDiv(balance1, params.liquidity, strategy.account.totalShares);

            amount0 += userShare0;
            amount1 += userShare1;

            balance0 -= userShare0;
            balance1 -= userShare1;

            strategy.account.balance0 = balance0;
            strategy.account.balance1 = balance1;
        }

        if (amount0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), amount0);
        }

        if (amount1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), amount1);
        }

        position.liquidityShare -= params.liquidity;
        strategy.account.totalShares -= params.liquidity;
        strategy.account.uniswapLiquidity -= liquidity;

        emit Withdraw(params.tokenId, params.recipient, params.liquidity, amount0, amount1);
    }

    /// @inheritdoc ICLTBase
    function claimPositionFee(ClaimFeesParams calldata params) external override isAuthorizedForToken(params.tokenId) {
        UserPositions.Data storage position = positions[params.tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        if (strategy.isCompound) revert onlyNonCompounders();
        if (position.liquidityShare == 0) revert NoLiquidity();

        strategy.updatePositionFee();

        (uint128 tokensOwed0, uint128 tokensOwed1) = position.claimPositionAmounts(strategy);

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
            PoolActions.burnLiquidity(strategy.key, strategy.account.uniswapLiquidity);

        // deduct any fees if required for protocol
        (uint256 automationFee,,,) = _getGovernanceFee(strategy.isPrivate);

        // returns protocols feeses
        (amount0Added, amount1Added) = transferFee(strategy.key, 0, automationFee, amount0, amount1, address(0), owner);

        amount0 -= amount0Added;
        amount1 -= amount1Added;

        if (strategy.isCompound) {
            amount0 += fees0 + strategy.account.balance0;
            amount1 += fees1 + strategy.account.balance1;
        }

        if (params.swapAmount != 0) {
            (int256 amount0Swapped, int256 amount1Swapped) =
                PoolActions.swapToken(params.key.pool, params.zeroForOne, params.swapAmount);

            (amount0, amount1) = PoolActions.amountsDirection(
                params.zeroForOne,
                amount0,
                amount1,
                uint256(amount0Swapped < 0 ? -amount0Swapped : amount0Swapped),
                uint256(amount1Swapped < 0 ? -amount1Swapped : amount1Swapped)
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

        emit LiquidityShifted(params.strategyId, params.shouldMint, params.zeroForOne, params.swapAmount);
    }

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

        strategy.updateStrategyState(owner, managementFee, performanceFee, abi.encode(actions));

        emit StrategyUpdated(strategyId);
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
            strategy.account.uniswapLiquidity,
            amount0Desired,
            amount1Desired,
            strategy.account.balance0,
            strategy.account.balance1,
            strategy.account.totalShares
        );

        // liquidity frontrun checks here
        if (share == 0) revert InvalidShare();

        if (strategy.account.totalShares == 0) {
            if (share < Constants.MIN_INITIAL_SHARES) revert InvalidShare();
        }

        pay(strategy.key.pool.token0(), _msgSender(), address(this), amount0);
        pay(strategy.key.pool.token1(), _msgSender(), address(this), amount1);

        // bug we need to track the liquidity amounts of all users in a single strategy & that value will be used in
        // shifting of liquidity for each strategy
        // ideally in child pattern there's only one position for that contract at a time
        // (TL, TU, Owner) => total uniswapLiquidity added by the contract
        // but here multiple positions could be open at a time for same ticks so if we do
        // (TL, TU, Owner) => uniswapLiquidity: it will pull all other strategies liquidity which is having the same
        // ticks that are not meant to be pulled.

        // now contract balance has: new user asset + previous user unused assets
        (uint128 liquidityAdded, uint256 amount0Added, uint256 amount1Added) =
            PoolActions.mintLiquidity(strategy.key, amount0, amount1);

        strategy.update(liquidityAdded, share, amount0, amount1, amount0Added, amount1Added);

        // optimize above and below states
        if (strategy.isCompound) {
            /// should set these vars zero if not added : above values should not use
            (liquidityAdded, amount0Added, amount1Added) =
                PoolActions.compoundFees(strategy.key, strategy.account.balance0, strategy.account.balance1);

            strategy.updateForCompound(liquidityAdded, amount0Added, amount1Added);
        }

        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(_msgSender(), address(this).balance);
        }

        feeGrowthInside0LastX128 = strategy.account.feeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = strategy.account.feeGrowthInside1LastX128;
    }

    function getUserfee(uint256 tokenId) external returns (uint256 fee0, uint256 fee1) {
        UserPositions.Data storage position = positions[tokenId];
        StrategyData storage strategy = strategies[position.strategyId];

        strategy.updatePositionFee();

        (fee0, fee1) = position.claimPositionAmounts(strategy);
    }

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

    function updateFees(StrategyKey memory key) external {
        key.pool.burn(key.tickLower, key.tickUpper, 0);
    }
}
