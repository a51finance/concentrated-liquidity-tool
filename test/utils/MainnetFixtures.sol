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

        _hevm.prank(recepient);
        token0.approve(address(router), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(router), type(uint256).max);
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

        cltModules = new CLTModules(recepient);

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

    function getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
    }

    function initStrategy(int24 difference) public {
        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - difference, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + difference, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
    }
}
