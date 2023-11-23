// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { Utilities } from "./Utilities.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/console.sol";

contract Fixtures is UniswapDeployer {
    IUniswapV3Factory factory;
    IUniswapV3Pool pool;
    SwapRouter router;
    WETH weth;

    CLTBase base;
    RebaseModule rebaseModule;
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

    function initBase() internal {
        weth = new WETH();
        base = new CLTBase("ALP Base", "ALP", address(this), address(weth), 10e14, factory);
        rebaseModule = new RebaseModule(msg.sender, address(base));

        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModule), true);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModule), true);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModule), true);
    }

    function deployFreshState() internal {
        ERC20Mock[] memory tokens = deployTokens(2, 1e50);

        if (address(tokens[0]) >= address(tokens[1])) {
            (token0, token1) = (tokens[1], tokens[0]);
        }

        initPool();
        initBase();
    }

    function getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
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
