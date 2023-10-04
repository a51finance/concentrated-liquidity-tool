// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTBase.sol";

import "./base/CLTPayments.sol";

import "./libraries/Position.sol";
import "./libraries/PoolActions.sol";

import "@solmate/auth/Owned.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTBase is ICLTBase, CLTPayments, Owned, ERC721 {
    uint256 private _nextId = 1;

    // keccak256("MODE")
    bytes32 public constant MODE = 0x25d202ee31c346b8c1099dc1a469d77ca5ac14ed43336c881902290b83e0a13a;

    // keccak256("EXIT_STRATEGY")
    bytes32 public constant EXIT_STRATEGY = 0xf36a697ed62dd2d982c1910275ee6172360bf72c4dc9f3b10f2d9c700666e227;

    // keccak256("REBASE_PREFERENCE")
    bytes32 public constant REBASE_PREFERENCE = 0x34853121256845a303eb4d68b2f8d3be15720bd989805c7b91bdf400398c4482;

    // keccak256("LIQUIDITY_DISTRIBUTION")
    bytes32 public constant LIQUIDITY_DISTRIBUTION = 0xeabe6f62bd74d002b0267a6aaacb5212bb162f4f87ee1c4a80ac0d2698f8a505;

    mapping(bytes32 => uint64[]) private modules;

    mapping(bytes32 => StrategyData) private strategies;

    mapping(uint256 => Position.Data) private positions;

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

    function createStrategy(PositionActions calldata actions, StrategyKey calldata key, bool isCompound) external {
        // add some checks here for inputs
        bytes32 strategyID = keccak256(abi.encode(msg.sender, _nextId++));

        bytes32 positionActionsHash = keccak256(abi.encode(actions));

        strategies[strategyID] = StrategyData({
            key: key,
            positionActions: positionActionsHash,
            isCompound: isCompound,
            balance0: 0,
            balance1: 0,
            totalShares: 0
        });

        emit StrategyCreated(strategyID, positionActionsHash, key, isCompound);
    }

    function deposit(DepositParams calldata params)
        external
        payable
        override
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        StrategyData storage strategy = strategies[params.strategyId];

        (liquidity, amount0, amount1) =
            PoolActions.mintLiquidity(strategy.key, params.amount0Desired, params.amount1Desired, msg.sender);

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "HOW");

        _mint(params.recipient, (tokenId = _nextId++));

        positions[tokenId] = Position.Data({
            strategyId: params.strategyId,
            liquidityShare: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        emit Deposit(params.strategyId, tokenId, liquidity, amount0, amount1);
    }

    function withdraw(WithdrawParams calldata params) external {
        PoolActions.burnUserLiquidity(params.key, params.userSharePercentage, params.recipient);
    }

    function claim(ClaimFeesParams calldata params) external {
        PoolActions.collectPendingFees(params.key, params.recipient);
    }

    function shiftLiquidity(ShiftLiquidityParams calldata params) external {
        // checks
        PoolActions.checkRange(params.key.tickLower, params.key.tickUpper, params.key.pool.tickSpacing());

        StrategyData storage strategy = strategies[params.strategyId];

        (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) =
            PoolActions.burnLiquidity(strategy.key, address(this));

        // deduct any fees if required for protocol

        // no swapping required for now
        if (params.swapAmount != 0) {
            PoolActions.swapToken(params.key.pool, address(this), params.zeroForOne, params.swapAmount);
        }

        // custom amount0 or amount1 should be added for next time
        PoolActions.mintLiquidity(params.key, amount0, amount1, address(this));

        // update state { this state will be reflected to all users having this strategyID }
        strategy.key = params.key;
    }

    function addModule(bytes32 moduleKey, uint64[] calldata newModule) external onlyOwner {
        if (
            moduleKey != MODE || moduleKey != REBASE_PREFERENCE || moduleKey != EXIT_STRATEGY
                || moduleKey != LIQUIDITY_DISTRIBUTION
        ) revert InvalidModule(moduleKey);

        modules[moduleKey] = newModule;
    }
}
