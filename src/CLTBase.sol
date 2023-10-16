// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTBase.sol";

import "./base/CLTPayments.sol";

import "./libraries/Position.sol";
import "./libraries/PoolActions.sol";
import "./libraries/FixedPoint128.sol";
import "./libraries/LiquidityShares.sol";
import "./libraries/SafeCastExtended.sol";

import "@solmate/auth/Owned.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTBase is ICLTBase, CLTPayments, Owned, ERC721 {
    using Position for StrategyData;
    using SafeCastExtended for uint256;

    uint256 private _nextId = 1;
    uint256 public constant MIN_INITIAL_SHARES = 1e3;

    // keccak256("MODE")
    bytes32 public constant MODE = 0x25d202ee31c346b8c1099dc1a469d77ca5ac14ed43336c881902290b83e0a13a;

    // keccak256("EXIT_STRATEGY")
    bytes32 public constant EXIT_STRATEGY = 0xf36a697ed62dd2d982c1910275ee6172360bf72c4dc9f3b10f2d9c700666e227;

    // keccak256("REBASE_PREFERENCE")
    bytes32 public constant REBASE_PREFERENCE = 0x34853121256845a303eb4d68b2f8d3be15720bd989805c7b91bdf400398c4482;

    // keccak256("LIQUIDITY_DISTRIBUTION")
    bytes32 public constant LIQUIDITY_DISTRIBUTION = 0xeabe6f62bd74d002b0267a6aaacb5212bb162f4f87ee1c4a80ac0d2698f8a505;

    mapping(bytes32 => uint64[]) public modules;

    mapping(bytes32 => StrategyData) public strategies;

    mapping(uint256 => Position.Data) public positions;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _weth9,
        IUniswapV3Factory _factory
    )
        Owned(_owner)
        ERC721(_name, _symbol)
        CLTPayments(_factory, _weth9)
    { }

    function createStrategy(
        StrategyKey calldata key,
        ActionsData calldata data,
        PositionActions calldata actions,
        bool isCompound
    )
        external
    {
        // add some checks here for inputs
        bytes32 strategyID = keccak256(abi.encode(msg.sender, _nextId++));

        bytes memory actionsDataHash = abi.encode(data);
        bytes memory positionActionsHash = abi.encode(actions);

        strategies[strategyID] = StrategyData({
            key: key,
            actions: positionActionsHash,
            actionsData: actionsDataHash,
            isCompound: isCompound,
            balance0: 0,
            balance1: 0,
            totalShares: 0,
            uniswapLiquidity: 0
        });

        emit StrategyCreated(strategyID, positionActionsHash, actionsDataHash, key, isCompound);
    }

    function deposit(DepositParams calldata params)
        external
        payable
        override
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
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

        emit Deposit(params.strategyId, tokenId, share, amount0, amount1);
    }

    function updatePositionLiquidity(UpdatePositionParams calldata params)
        external
        returns (uint256 share, uint256 amount0, uint256 amount1)
    {
        Position.Data storage position = positions[params.tokenId];

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

        // add liquidity share for compounders while non compounders can withdraw all liquidity
        uint256 fees0;
        uint256 fees1;

        if (strategy.isCompound) {
            uint256 liquidityShare = FullMath.mulDiv(params.liquidity, 1e18, strategy.totalShares);

            (amount0, amount1, fees0, fees1) =
                PoolActions.burnUserLiquidity(strategy.key, strategy.uniswapLiquidity, liquidityShare);
        } else {
            (amount0, amount1) =
                strategy.key.pool.burn(strategy.key.tickLower, strategy.key.tickUpper, positionLiquidity.toUint128());

            (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) =
                PoolActions.getPositionLiquidity(strategy.key);

            amount0 += uint128(position.tokensOwed0)
                + uint128(
                    FullMath.mulDiv(
                        feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128, positionLiquidity, FixedPoint128.Q128
                    )
                );

            amount1 += uint128(position.tokensOwed1)
                + uint128(
                    FullMath.mulDiv(
                        feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128, positionLiquidity, FixedPoint128.Q128
                    )
                );

            position.tokensOwed0 = 0;
            position.tokensOwed1 = 0;

            position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;

            strategy.key.pool.collect(
                address(this), strategy.key.tickLower, strategy.key.tickUpper, amount0.toUint128(), amount1.toUint128()
            );
        }

        // transfer fees of protocol

        // calculate user's total no of tokens [0,1], both handled Compounders, Non Compounders
        amount0 += FullMath.mulDiv(strategy.balance0 + fees0, params.liquidity, strategy.totalShares);
        amount1 += FullMath.mulDiv(strategy.balance1 + fees1, params.liquidity, strategy.totalShares);

        if (amount0 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token0(), amount0);
        }

        if (amount1 > 0) {
            transferFunds(params.refundAsETH, params.recipient, strategy.key.pool.token1(), amount1);
        }

        // recheck for both scenerios
        position.liquidityShare = positionLiquidity - params.liquidity;

        // mint additional fees for compounders
        // update state.balance[0, 1] again after compounding fee from balance and collected fee
        // ✔ update feeGrowth for non compounders
    }

    function claimPositionFee(ClaimFeesParams calldata params) external isAuthorizedForToken(params.tokenId) {
        Position.Data storage position = positions[params.tokenId];

        if (position.liquidityShare == 0) revert NoLiquidity();
        if (strategies[position.strategyId].isCompound) revert onlyNonCompounders();

        (uint128 tokensOwed0, uint128 tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);

        PoolActions.updatePosition(params.key);

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) =
            PoolActions.getPositionLiquidity(params.key);

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

        (uint256 amount0Collected, uint256 amount1Collected) =
            PoolActions.collectPendingFees(params.key, tokensOwed0, tokensOwed1, params.recipient);

        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        emit Collect(params.tokenId, params.recipient, amount0Collected, amount1Collected);
    }

    function shiftLiquidity(ShiftLiquidityParams calldata params) external override {
        // checks
        PoolActions.checkRange(params.key.tickLower, params.key.tickUpper, params.key.pool.tickSpacing());

        StrategyData storage strategy = strategies[params.strategyId];

        // some checks here for key.ticks validation according to new position

        uint256 amount0;
        uint256 amount1;

        // only burn this strategy liquidity not others
        (amount0, amount1,,) = PoolActions.burnLiquidity(strategy.key, strategy.uniswapLiquidity);

        // deduct any fees if required for protocol

        if (strategy.isCompound) {
            amount0 += strategy.balance0;
            amount1 += strategy.balance1;
        }

        if (params.swapAmount != 0) {
            (int256 amount0Swapped, int256 amount1Swapped) =
                PoolActions.swapToken(params.key.pool, params.zeroForOne, params.swapAmount);

            (amount0, amount1) = PoolActions.amountsDirection(
                params.zeroForOne, amount0, amount1, uint256(amount0Swapped), uint256(amount1Swapped)
            );
        }

        uint128 liquidity;
        uint256 amount0Added;
        uint256 amount1Added;

        if (params.shouldMint) {
            (liquidity, amount0Added, amount1Added) = PoolActions.mintLiquidity(params.key, amount0, amount1);
        }

        // update state { this state will be reflected to all users having this strategyID }
        strategy.updateStrategy(params.key, liquidity, amount0 - amount0Added, amount1 - amount1Added);
    }

    function addModule(bytes32 moduleKey, uint64[] calldata newModule) external onlyOwner {
        if (
            moduleKey != MODE || moduleKey != REBASE_PREFERENCE || moduleKey != EXIT_STRATEGY
                || moduleKey != LIQUIDITY_DISTRIBUTION
        ) revert InvalidModule(moduleKey);

        modules[moduleKey] = newModule;
    }

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

        (share, amount0, amount1, feeGrowthInside0LastX128, feeGrowthInside1LastX128) = LiquidityShares
            .computeLiquidityShare(
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
            if (share < MIN_INITIAL_SHARES) revert InvalidShare();
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
    }

    function validateInputData() private {
        // fetch updated address of all modules and send data for validation
    }
}
