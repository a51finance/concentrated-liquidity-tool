// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import { WETH } from "../mocks/WETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { Modes } from "../../src/modules/rebasing/Modes.sol";
import { CLTTwapQuoter } from "../../src/CLTTwapQuoter.sol";

import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../../src/interfaces/IGovernanceFeeHandler.sol";

import { GovernanceFeeHandler } from "../../src/GovernanceFeeHandler.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";

import { Utilities } from "./Utilities.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { SwapRouter } from "@cryptoalgebra/periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@cryptoalgebra/periphery/contracts/interfaces/ISwapRouter.sol";
import { AlgebraPoolDeployer } from "@cryptoalgebra/integral-core/contracts/AlgebraPoolDeployer.sol";
import { NonfungiblePositionManager } from "@cryptoalgebra/periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from
    "@cryptoalgebra/periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { AlgebraFactory } from "@cryptoalgebra/integral-core/contracts/AlgebraFactory.sol";
import { AlgebraPool } from "@cryptoalgebra/integral-core/contracts/AlgebraPool.sol";

import { LiquidityAmounts } from "@cryptoalgebra/periphery/contracts/libraries/LiquidityAmounts.sol";
import { TickMath } from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import { IAlgebraPool } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import { IAlgebraFactory } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";

contract RebaseFixtures is UniswapDeployer, Utilities {
    NonfungiblePositionManager positionManager;
    AlgebraPoolDeployer deployer;
    IAlgebraPool pool;
    SwapRouter router;

    ICLTBase.StrategyKey strategyKey;
    RebaseModule rebaseModule;
    CLTModules cltModules;
    CLTBase base;
    Modes modes;
    CLTTwapQuoter cltTwap;

    ERC20Mock token0;
    ERC20Mock token1;
    WETH weth;

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

    function initPool(address recepient) internal returns (IAlgebraFactory factory) {
        INonfungiblePositionManager.MintParams memory mintParams;
        ERC20Mock[] memory tokens = deployTokens(recepient, 2, 1e50);

        token0 = tokens[0];
        token1 = tokens[1];

        if (token0 >= token1) {
            (token0, token1) = (token1, token0);
        }

        // intialize algebra contracts
        deployer = new AlgebraPoolDeployer(address(1));
        factory = new AlgebraFactory(address(deployer));

        factory.createPool(address(token0), address(token1));
        pool = IAlgebraPool(factory.poolByPair(address(token0), address(token1)));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));

        router = new SwapRouter(address(factory), address(weth), address(deployer));
        positionManager =
            new NonfungiblePositionManager(address(factory), address(weth), address(factory), address(deployer));

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.tickUpper = (600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.recipient = recepient;
        mintParams.amount0Desired = 1000e18;
        mintParams.amount1Desired = 1000e18;
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
        swapParams.recipient = recipient;
        swapParams.deadline = block.timestamp + 100;
        swapParams.amountIn = amountIn;
        swapParams.amountOutMinimum = amountOutMinimum;
        swapParams.limitSqrtPrice = sqrtPriceLimitX96;

        _hevm.prank(recipient);
        router.exactInputSingle(swapParams);
    }

    function generateMultipleSwapsWithTime(address recipient) public {
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, recipient, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, recipient, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, recipient, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, recipient, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
    }

    function initBase(address recepient) internal {
        IAlgebraFactory factory;

        (factory) = initPool(recepient);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        cltTwap = new CLTTwapQuoter(address(this));
        cltModules = new CLTModules(address(this));

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(feeParams, feeParams);

        base = new CLTBase(
            "ALP Base", "ALP", address(this), address(weth), address(feeHandler), address(cltModules), factory
        );

        _hevm.prank(recepient);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(base), type(uint256).max);

        modes = new Modes(address(base), address(cltTwap), address(this));
        rebaseModule = new RebaseModule(address(this), address(base), address(cltTwap));

        _hevm.prank(recepient);
        rebaseModule.toggleOperator(recepient);

        _hevm.prank(recepient);
        base.toggleOperator(address(rebaseModule));

        _hevm.prank(recepient);
        base.toggleOperator(address(modes));

        _hevm.prank(recepient);
        cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(rebaseModule));
        _hevm.prank(recepient);
        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));
        _hevm.prank(recepient);
        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"));
        _hevm.prank(recepient);
        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"));
    }

    function initStrategy(int24 difference) public {
        (, int24 tick,,,,) = pool.globalState();

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

    function createBasicStrategy(int24 difference, address recepient, bool isCompunded, uint256 mode) public {
        initStrategy(difference);
        ICLTBase.PositionActions memory positionActions;

        positionActions.mode = mode;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        _hevm.prank(recepient);
        base.createStrategy(strategyKey, positionActions, 0, 0, isCompunded, false);
    }

    function createStrategyAndDeposit(
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
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
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

    function depoit(bytes32 strategyID, address recepient, uint256 amount0, uint256 amount1) public {
        ICLTBase.DepositParams memory depositParams;

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = amount0;
        depositParams.amount1Desired = amount1;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = recepient;

        _hevm.prank(recepient);
        base.deposit(depositParams);
    }

    function createStrategyAndDepositWithActions(
        address owner,
        bool isCompunded,
        uint256 mode,
        uint256 positionId
    )
        public
        returns (bytes32 strategyID, ICLTBase.StrategyKey memory key)
    {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        strategyID = createStrategyAndDeposit(rebaseActions, 1500, owner, positionId, mode, isCompunded);
        (key,,,,,,,,) = base.strategies(strategyID);
    }

    function getStrategyReserves(
        ICLTBase.StrategyKey memory keyInput,
        uint128 liquidityDesired
    )
        internal
        view
        returns (uint256 reserves0, uint256 reserves1)
    {
        (uint160 sqrtPriceX96,,,,,) = keyInput.pool.globalState();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(keyInput.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(keyInput.tickUpper);

        if (liquidityDesired > 0) {
            (reserves0, reserves1) =
                LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidityDesired);
        }
    }

    function checkRange(int24 tickLower, int24 tickUpper) public view returns (bool) {
        (, int24 tick,,,,) = pool.globalState();

        if (tick > tickLower && tick < tickUpper) return true;
        return false;
    }

    function allowNewUser(address user, address owner, uint256 amount) public {
        _hevm.prank(owner);
        token0.transfer(user, amount);
        _hevm.prank(owner);
        token1.transfer(user, amount);

        _hevm.prank(user);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(user);
        token1.approve(address(base), type(uint256).max);
    }
}
