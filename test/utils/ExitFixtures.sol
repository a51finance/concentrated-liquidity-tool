// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { Modes } from "../../src/modules/rebasing/Modes.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { CLTTwapQuoter } from "../../src/CLTTwapQuoter.sol";

import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../../src/interfaces/IGovernanceFeeHandler.sol";

import { GovernanceFeeHandler } from "../../src/GovernanceFeeHandler.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";
import { ExitModule } from "../../src/modules/Exit/ExitModule.sol";

import { Utilities } from "./Utilities.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { Quoter } from "@uniswap/v3-periphery/contracts/lens/Quoter.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { console } from "forge-std/console.sol";

contract ExitFixtures is UniswapDeployer, Utilities {
    NonfungiblePositionManager positionManager;
    IUniswapV3Pool pool;
    SwapRouter router;
    Quoter quote;

    ICLTBase.StrategyKey strategyKey;
    GovernanceFeeHandler feeHandler;
    RebaseModule rebaseModule;
    ExitModule exitModule;
    CLTModules cltModules;
    CLTBase base;
    Modes modes;
    CLTTwapQuoter cltTwap;

    ERC20Mock token0;
    ERC20Mock token1;
    WETH weth;

    struct TickCalculatingVars {
        int24 ntl;
        int24 ntu;
        int24 ntlp;
        int24 ntup;
        int24 td;
    }

    function deployTokens(
        address recepient,
        uint8 count,
        uint256 totalSupply
    )
        public
        returns (ERC20Mock[] memory tokens)
    {
        weth = new WETH();
        tokens = new ERC20Mock[](count);
        for (uint8 i = 0; i < count; i++) {
            tokens[i] = new ERC20Mock();
            tokens[i].mint(recepient, totalSupply);
        }
    }

    function initPool(
        address recepient,
        uint256 initialAmount0,
        uint256 initialAmount1
    )
        internal
        returns (IUniswapV3Factory factory)
    {
        INonfungiblePositionManager.MintParams memory mintParams;
        ERC20Mock[] memory tokens = deployTokens(recepient, 2, 1e50);

        token0 = tokens[0];
        token1 = tokens[1];

        if (token0 >= token1) {
            (token0, token1) = (token1, token0);
        }

        // intialize uniswap contracts
        factory = IUniswapV3Factory(deployUniswapV3Factory());
        pool = IUniswapV3Pool(factory.createPool(address(token0), address(token1), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
        router = new SwapRouter(address(factory), address(weth));
        positionManager = new NonfungiblePositionManager(address(factory), address(weth), address(factory));
        pool.increaseObservationCardinalityNext(80);
        quote = new Quoter(address(factory), address(weth));

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.tickUpper = (600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.fee = 500;
        mintParams.recipient = recepient;
        mintParams.amount0Desired = initialAmount0;
        mintParams.amount1Desired = initialAmount1;
        mintParams.amount0Min = 0;
        mintParams.amount1Min = 0;
        mintParams.deadline = 2_000_000_000;

        _hevm.prank(recepient);
        token0.approve(address(positionManager), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(positionManager), type(uint256).max);

        _hevm.prank(recepient);
        token0.approve(address(router), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(router), type(uint256).max);

        _hevm.prank(recepient);
        positionManager.mint(mintParams);

        generateMultipleSwapsWithTime(recepient);
    }

    function executeSwap(
        ERC20Mock tokenIn,
        ERC20Mock tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    )
        public
    {
        ISwapRouter.ExactInputSingleParams memory swapParams;

        swapParams.tokenIn = address(tokenIn);
        swapParams.tokenOut = address(tokenOut);
        swapParams.fee = fee;
        swapParams.recipient = recipient;
        swapParams.deadline = block.timestamp + 100;
        swapParams.amountIn = amountIn;
        swapParams.amountOutMinimum = amountOutMinimum;
        swapParams.sqrtPriceLimitX96 = sqrtPriceLimitX96;

        _hevm.prank(recipient);
        router.exactInputSingle(swapParams);
    }

    function generateMultipleSwapsWithTime(address recipient) public {
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, 500, recipient, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, 500, recipient, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, 500, recipient, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, 500, recipient, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
    }

    function initBase(address recepient, uint256 initialAmount0, uint256 initialAmount1) internal {
        IUniswapV3Factory factory;

        (factory) = initPool(recepient, initialAmount0, initialAmount1);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        cltTwap = new CLTTwapQuoter(address(this));
        cltModules = new CLTModules(address(this));

        feeHandler = new GovernanceFeeHandler(address(this), feeParams, feeParams);

        base = new CLTBase("ALP Base", "ALP", recepient, address(0), address(feeHandler), address(cltModules), factory);

        _hevm.prank(recepient);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(base), type(uint256).max);

        modes = new Modes(address(base), address(cltTwap), recepient);
        rebaseModule = new RebaseModule(recepient, address(base), address(cltTwap));
        exitModule = new ExitModule(recepient, address(base), address(cltTwap));

        _hevm.startPrank(recepient);

        rebaseModule.toggleOperator(recepient);

        base.toggleOperator(address(rebaseModule));

        base.toggleOperator(address(exitModule));

        base.toggleOperator(address(modes));

        cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(rebaseModule));

        cltModules.setModuleAddress(keccak256("EXIT_STRATEGY"), address(exitModule));

        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));

        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("ACTIVE_REBALANCE"));

        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"));

        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"));

        cltModules.setNewModule(keccak256("EXIT_STRATEGY"), keccak256("EXIT_PREFERENCE"));

        _hevm.stopPrank();
    }

    function initStrategy(int24 difference) public {
        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - difference, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + difference, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
    }

    function getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
    }

    function createStrategyActions(
        int24 difference,
        address recepient,
        bool isCompunded,
        ICLTBase.PositionActions memory positionActions
    )
        internal
    {
        initStrategy(difference);
        positionActions.mode = positionActions.mode;
        positionActions.exitStrategy = positionActions.exitStrategy;
        positionActions.rebaseStrategy = positionActions.rebaseStrategy;
        positionActions.liquidityDistribution = positionActions.liquidityDistribution;
        _hevm.prank(recepient);
        base.createStrategy(strategyKey, positionActions, 0, 0, isCompunded, false);
    }

    function createStrategyAndDeposit(
        ICLTBase.StrategyPayload[] memory exitActions,
        ICLTBase.StrategyPayload[] memory rebaseActions,
        int24 difference,
        address recepient,
        uint256 positionId,
        uint256 mode,
        bool isCompounded
    )
        public
        returns (bytes32 strategyID)
    {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;

        positionActions.mode = mode;
        positionActions.exitStrategy = exitActions;
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(difference, recepient, isCompounded, positionActions);

        strategyID = getStrategyID(recepient, positionId);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = recepient;

        _hevm.prank(recepient);
        base.deposit(depositParams);
    }

    function getAllTicks(
        bytes32 strategyID,
        bytes memory actionsData,
        bool shouldLog
    )
        public
        view
        returns (int24 tlp, int24 tup, int24 t)
    {
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        t = cltTwap.getTwap(key.pool);

        (tlp, tup) = abi.decode(actionsData, (int24, int24));

        if (shouldLog) {
            console.logInt(tlp);
            console.logInt(tup);
            console.logInt(t);
        }
    }

    function getAllTicksR(
        bytes32 strategyID,
        bytes32 actionName,
        bytes memory actionsData,
        bool shouldLog
    )
        public
        returns (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t)
    {
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        (, t,,,,,) = pool.slot0();

        tl = key.tickLower;
        tu = key.tickUpper;

        (tlp, tup,,) = rebaseModule.getPreferenceTicks(strategyID, actionName, actionsData);

        if (shouldLog) {
            console.logInt(tl);
            console.logInt(tlp);
            console.logInt(t);
            console.logInt(tup);
            console.logInt(tu);
        }
    }

    // function createStrategyAndDepositWithAmount(
    //     ICLTBase.StrategyPayload[] memory rebaseActions,
    //     int24 difference,
    //     address recepient,
    //     uint256 positionId,
    //     uint256 mode,
    //     bool isCompounded,
    //     uint256 amount0,
    //     uint256 amount1
    // )
    //     public
    //     returns (bytes32 strategyID)
    // {
    //     ICLTBase.PositionActions memory positionActions;
    //     ICLTBase.DepositParams memory depositParams;

    //     positionActions.mode = mode;
    //     positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
    //     positionActions.rebaseStrategy = rebaseActions;
    //     positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

    //     createStrategyActions(difference, recepient, isCompounded, positionActions);

    //     strategyID = getStrategyID(recepient, positionId);

    //     depositParams.strategyId = strategyID;
    //     depositParams.amount0Desired = amount0;
    //     depositParams.amount1Desired = amount1;
    //     depositParams.amount0Min = 0;
    //     depositParams.amount1Min = 0;
    //     depositParams.recipient = recepient;

    //     _hevm.prank(recepient);
    //     base.deposit(depositParams);
    // }

    // function depoit(bytes32 strategyID, address recepient, uint256 amount0, uint256 amount1) public {
    //     ICLTBase.DepositParams memory depositParams;

    //     depositParams.strategyId = strategyID;
    //     depositParams.amount0Desired = amount0;
    //     depositParams.amount1Desired = amount1;
    //     depositParams.amount0Min = 0;
    //     depositParams.amount1Min = 0;
    //     depositParams.recipient = recepient;

    //     _hevm.prank(recepient);
    //     base.deposit(depositParams);
    // }

    // function createStrategyAndDepositWithActions(
    //     address owner,
    //     bool isCompunded,
    //     uint256 mode,
    //     uint256 positionId
    // )
    //     public
    //     returns (bytes32 strategyID, ICLTBase.StrategyKey memory key)
    // {
    //     ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
    //     rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
    //     rebaseActions[0].data = abi.encode(10, 30);

    //     strategyID = createStrategyAndDeposit(rebaseActions, 1500, owner, positionId, mode, isCompunded);
    //     (key,,,,,,,,) = base.strategies(strategyID);
    // }

    // function getStrategyReserves(
    //     ICLTBase.StrategyKey memory keyInput,
    //     uint128 liquidityDesired
    // )
    //     internal
    //     view
    //     returns (uint256 reserves0, uint256 reserves1)
    // {
    //     (uint160 sqrtPriceX96,,,,,,) = keyInput.pool.slot0();
    //     uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(keyInput.tickLower);
    //     uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(keyInput.tickUpper);

    //     if (liquidityDesired > 0) {
    //         (reserves0, reserves1) =
    //             LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96,
    // liquidityDesired);
    //     }
    // }

    // function checkRange(int24 tickLower, int24 tickUpper) public view returns (bool) {
    //     (, int24 tick,,,,,) = pool.slot0();

    //     if (tick > tickLower && tick < tickUpper) return true;
    //     return false;
    // }

    // function allowNewUser(address user, address owner, uint256 amount) public {
    //     _hevm.prank(owner);
    //     token0.transfer(user, amount);
    //     _hevm.prank(owner);
    //     token1.transfer(user, amount);

    //     _hevm.prank(user);
    //     token0.approve(address(base), type(uint256).max);
    //     _hevm.prank(user);
    //     token1.approve(address(base), type(uint256).max);
    // }

    // function getAmounts(int24 tickLower, int24 tickUpper, uint256 amount0) public returns (uint256, uint256) {
    //     uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
    //         TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), amount0
    //     );

    //     uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
    //         TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
    //     );
    //     return (amount0, amount1);
    // }

    // function createActiveRebalancingAndDeposit(
    //     address owner,
    //     int24 tick,
    //     int24 tickLower,
    //     int24 tickUpper,
    //     int24 lowerDiff,
    //     int24 upperDiff
    // )
    //     public
    //     returns (bytes32 strategyID, bytes memory data, ICLTBase.PositionActions memory positionActions)
    // {
    //     ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
    //     ICLTBase.DepositParams memory depositParams;

    //     executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
    //     executeSwap(token0, token1, pool.fee(), owner, 22e18, 0, 0);

    //     strategyKey.pool = pool;
    //     strategyKey.tickLower = tickLower;
    //     strategyKey.tickUpper = tickUpper;
    //     data = abi.encode(lowerDiff, upperDiff, tick, tickLower, tickUpper);
    //     rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
    //     rebaseActions[0].data = data;

    //     rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
    //     rebaseActions[1].data = abi.encode(3);

    //     positionActions.mode = 3;
    //     positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
    //     positionActions.rebaseStrategy = rebaseActions;
    //     positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

    //     base.createStrategy(strategyKey, positionActions, 0, 0, false, false);

    //     strategyID = getStrategyID(address(this), 1);

    //     depositParams.strategyId = strategyID;
    //     depositParams.amount0Desired = 100e18;
    //     depositParams.amount1Desired = 100e18;
    //     depositParams.amount0Min = 0;
    //     depositParams.amount1Min = 0;
    //     depositParams.recipient = address(this);
    //     base.deposit(depositParams);
    // }
}
