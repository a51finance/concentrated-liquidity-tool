// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { console } from "forge-std/console.sol";

import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { RebaseModuleMock } from "../mocks/RebaseModule.mock.sol";

import { Utilities } from "./Utilities.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract RebaseFixtures is UniswapDeployer, Utilities {
    NonfungiblePositionManager positionManager;
    ICLTBase.StrategyKey strategyKey;
    RebaseModuleMock rebaseModule;
    SwapRouter router;
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

    function initPool(address recepient) internal returns (IUniswapV3Factory factory, IUniswapV3Pool pool) {
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
        positionManager = new
    NonfungiblePositionManager(address(factory),address(weth),address(factory));

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.tickUpper = (600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.fee = 500;
        mintParams.recipient = recepient;
        mintParams.amount0Desired = 1000e18;
        mintParams.amount1Desired = 100e18;
        mintParams.amount0Min = 0;
        mintParams.amount1Min = 0;
        mintParams.deadline = 2_000_000_000;

        _hevm.prank(recepient);
        token0.approve(address(positionManager), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(positionManager), type(uint256).max);

        _hevm.prank(recepient);
        positionManager.mint(mintParams);
        console.log("Position minted with nft id", positionManager.tokenOfOwnerByIndex(recepient, 0));
    }

    function initPostion() internal { }

    function initBase(address recepient) internal returns (CLTBase base, IUniswapV3Pool pool) {
        IUniswapV3Factory factory;

        (factory, pool) = initPool(recepient);

        base = new CLTBase("ALP Base", "ALP", recepient, address(0), 10e14, factory);

        _hevm.prank(recepient);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(base), type(uint256).max);

        rebaseModule = new RebaseModuleMock(recepient, address(base));

        _hevm.prank(recepient);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModule), true);
        _hevm.prank(recepient);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModule), true);
        _hevm.prank(recepient);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModule), true);
    }

    function initStrategy(IUniswapV3Pool pool, int24 difference) public {
        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + difference, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
    }

    function getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
    }

    function createStrategyActions(
        CLTBase baseContract,
        IUniswapV3Pool pool,
        int24 difference,
        address recepient,
        ICLTBase.PositionActions memory positionActions
    )
        internal
    {
        initStrategy(pool, difference);
        positionActions.mode = positionActions.mode;
        positionActions.exitStrategy = positionActions.exitStrategy;
        positionActions.rebaseStrategy = positionActions.rebaseStrategy;
        positionActions.liquidityDistribution = positionActions.liquidityDistribution;
        _hevm.prank(recepient);
        baseContract.createStrategy(strategyKey, positionActions, 1000, true);
    }

    function createStrategyAndDeposit(
        ICLTBase.StrategyPayload[] memory rebaseActions,
        CLTBase baseContract,
        IUniswapV3Pool poolContract,
        int24 difference,
        address recepient,
        uint256 positionId,
        uint256 mode
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

        createStrategyActions(baseContract, poolContract, difference, recepient, positionActions);

        strategyID = getStrategyID(recepient, positionId);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = recepient;

        _hevm.prank(recepient);
        baseContract.deposit(depositParams);
    }
}
