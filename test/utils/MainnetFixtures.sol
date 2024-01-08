// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";
import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { CLTBase } from "../../src/CLTBase.sol";
import { Modes } from "../../src/modules/rebasing/Modes.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { IGovernanceFeeHandler } from "../../src/interfaces/IGovernanceFeeHandler.sol";
import { GovernanceFeeHandler } from "../../src/GovernanceFeeHandler.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { RebaseModuleMock } from "../mocks/RebaseModule.mock.sol";
import { Utilities } from "./Utilities.sol";
import { UniswapDeployer } from "../lib/UniswapDeployer.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { Constants } from "./Constants.sol";

contract MainnetFixtures is Utilities {
    INonfungiblePositionManager positionManager;
    IUniswapV3Pool pool;
    ISwapRouter router;

    ICLTBase.StrategyKey strategyKey;
    RebaseModule rebaseModule;
    CLTModules cltModules;
    CLTBase base;
    Modes modes;

    ERC20Mock token0;
    ERC20Mock token1;

    function initPool(address recepient) internal returns (IUniswapV3Factory factory) {
        INonfungiblePositionManager.MintParams memory mintParams;
        pool = IUniswapV3Pool(Constants.POOL_ETHUSDC);
        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        if (token0 >= token1) {
            (token0, token1) = (token1, token0);
        }

        // intialize uniswap contracts
        factory = IUniswapV3Factory(Constants.FACTORY);
        pool = IUniswapV3Pool(Constants.POOL_ETHUSDC);
        router = ISwapRouter(Constants.ROUTER);
        positionManager = INonfungiblePositionManager(Constants.MANAGER);

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.tickUpper = (600_000 / pool.tickSpacing()) * pool.tickSpacing();
        mintParams.fee = 500;
        mintParams.recipient = recepient;
        mintParams.amount0Desired = 100_000e18;
        mintParams.amount1Desired = 50e18;
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
    }

    function initBase(address recepient) internal {
        IUniswapV3Factory factory;

        (factory) = initPool(recepient);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        cltModules = new CLTModules( recepient);

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(address(this), feeParams, feeParams);

        base = new CLTBase("ALP Base", "ALP", recepient, address(0), address(feeHandler), address(cltModules),
    factory);

        _hevm.prank(recepient);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(base), type(uint256).max);

        rebaseModule = new RebaseModule(recepient, address(base));

        modes = new Modes(address(base),recepient);

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
}
