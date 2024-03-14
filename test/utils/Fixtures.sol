// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";

import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../../src/interfaces/IGovernanceFeeHandler.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { CLTTwapQuoter } from "../../src/CLTTwapQuoter.sol";

import { Modes } from "../../src/modules/rebasing/Modes.sol";
import { GovernanceFeeHandler } from "../../src/GovernanceFeeHandler.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import "forge-std/console.sol";

contract Fixtures is UniswapDeployer {
    IUniswapV3Factory factory;
    IUniswapV3Pool pool;
    SwapRouter router;
    INonfungiblePositionManager manager;
    WETH weth;

    Modes modes;
    CLTBase base;
    CLTTwapQuoter cltTwap;
    RebaseModule rebaseModule;
    CLTModules cltModules;
    GovernanceFeeHandler feeHandler;
    ERC20Mock token0;
    ERC20Mock token1;

    function deployTokens(uint8 count, uint256 totalSupply) public returns (ERC20Mock[] memory tokens) {
        tokens = new ERC20Mock[](count);
        for (uint8 i = 0; i < count; i++) {
            tokens[i] = new ERC20Mock();
            tokens[i].mint(address(this), totalSupply);
        }
    }

    function initPool() internal {
        // intialize uniswap contracts
        factory = IUniswapV3Factory(deployUniswapV3Factory());
        pool = IUniswapV3Pool(factory.createPool(address(token0), address(token1), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
    }

    function initPoolAndAddLiquidity() internal {
        manager = new NonfungiblePositionManager(address(factory), address(weth), address(factory));

        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);

        manager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 500,
                tickLower: -300,
                tickUpper: 300,
                amount0Desired: 1e30,
                amount1Desired: 1e30,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 1 days
            })
        );
    }

    function initRouter() internal {
        router = new SwapRouter(address(factory), address(weth));

        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
    }

    function initManagerRoutersAndPoolsWithLiq() internal {
        deployFreshState();
        initRouter();
        initPoolAndAddLiquidity();
    }

    function initBase() internal {
        weth = new WETH();

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        cltTwap = new CLTTwapQuoter(address(this));
        cltModules = new CLTModules(address(this));
        feeHandler = new GovernanceFeeHandler(address(this), feeParams, feeParams);

        base = new CLTBase(
            "ALP Base", "ALP", address(this), address(weth), address(feeHandler), address(cltModules), factory
        );

        modes = new Modes(address(base), address(cltTwap), address(this));
        rebaseModule = new RebaseModule(msg.sender, address(base), address(cltTwap));

        cltModules.setNewModule(keccak256("EXIT_STRATEGY"), keccak256("SMART_EXIT"));
        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));
        cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"));
        cltModules.setNewModule(keccak256("LIQUIDITY_DISTRIBUTION"), keccak256("PRICE_RANGE"));

        cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(rebaseModule));
    }

    function deployFreshState() internal {
        ERC20Mock[] memory tokens = deployTokens(2, 1000e50);

        if (address(tokens[0]) >= address(tokens[1])) {
            (token0, token1) = (tokens[1], tokens[0]);
        } else {
            (token0, token1) = (tokens[0], tokens[1]);
        }

        initPool();
        initBase();
    }

    function getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
    }

    function getStrategyReserves(
        ICLTBase.StrategyKey memory keyInput,
        uint128 liquidityDesired
    )
        internal
        view
        returns (uint256 reserves0, uint256 reserves1)
    {
        (uint160 sqrtPriceX96,,,,,,) = keyInput.pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(keyInput.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(keyInput.tickUpper);

        if (liquidityDesired > 0) {
            (reserves0, reserves1) =
                LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidityDesired);
        }
    }

    function createStrategyActions(
        uint256 basicMode,
        uint256 advanceMode,
        uint256 timePreference,
        uint256 inactivityCounts,
        int24 lowerPreferenceDiff,
        int24 upperPreferenceDiff
    )
        internal
        pure
        returns (ICLTBase.PositionActions memory actions)
    {
        ICLTBase.StrategyPayload[] memory rebaseStrategyActions;

        if (advanceMode == 1) {
            rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

            rebaseStrategyActions[0].actionName = 0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b;
            rebaseStrategyActions[0].data = abi.encode(lowerPreferenceDiff, upperPreferenceDiff);
        }

        if (advanceMode == 2) {
            rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

            rebaseStrategyActions[0].actionName = 0x4036d2cde3df45671689d4979c1a0416dd81c5761f9d35cce34ae9a59728ccb2;
            rebaseStrategyActions[0].data = abi.encode(timePreference);
        }

        if (advanceMode == 3) {
            rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

            rebaseStrategyActions[0].actionName = 0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893;
            rebaseStrategyActions[0].data = abi.encode(inactivityCounts);
        }

        if (advanceMode == 4) {
            rebaseStrategyActions = new ICLTBase.StrategyPayload[](3);

            rebaseStrategyActions[0].actionName = 0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b;
            rebaseStrategyActions[0].data = abi.encode(lowerPreferenceDiff, upperPreferenceDiff);

            rebaseStrategyActions[1].actionName = 0x4036d2cde3df45671689d4979c1a0416dd81c5761f9d35cce34ae9a59728ccb2;
            rebaseStrategyActions[1].data = abi.encode(timePreference);

            rebaseStrategyActions[2].actionName = 0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893;
            rebaseStrategyActions[2].data = abi.encode(inactivityCounts);
        }

        actions = ICLTBase.PositionActions({
            mode: basicMode,
            exitStrategy: new ICLTBase.StrategyPayload[](0), // not available till now
            rebaseStrategy: rebaseStrategyActions,
            liquidityDistribution: new ICLTBase.StrategyPayload[](0) // not available till now
         });
    }
}
