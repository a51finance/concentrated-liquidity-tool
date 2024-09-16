// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { CLTBase } from "../../src/CLTBase.sol";
import { Modes } from "../../src/modules/rebasing/Modes.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { CLTTwapQuoter } from "../../src/CLTTwapQuoter.sol";

import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../../src/interfaces/IGovernanceFeeHandler.sol";
import { ICLTTwapQuoter } from "../../src/interfaces/ICLTTwapQuoter.sol";
import { ICLTModules } from "../../src/interfaces/ICLTModules.sol";
// import { ICLTModules } from "../../src/interfaces/ICLTModules.sol";

import { GovernanceFeeHandler } from "../../src/GovernanceFeeHandler.sol";
import { RebaseModule } from "../../src/modules/rebasing/RebaseModule.sol";

import { Utilities } from "./Utilities.sol";

import { UniswapDeployer } from "../lib/UniswapDeployer.sol";

import { WETH } from "@solmate/tokens/WETH.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import { Quoter } from "@uniswap/v3-periphery/contracts/lens/Quoter.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract MainnetFixtures is UniswapDeployer, Utilities {
    INonfungiblePositionManager positionManager;
    IUniswapV3Pool pool;
    ISwapRouter router;
    IQuoter quote;

    ICLTBase.StrategyKey strategyKey;
    IGovernanceFeeHandler feeHandler;
    RebaseModule rebaseModule;
    ICLTModules cltModules;
    CLTBase base;
    ICLTTwapQuoter cltTwap;
    Modes modes;

    IERC20 token0;
    IERC20 token1;
    WETH weth;

    // event StrategyCreated(bytes32 id);

    struct TickCalculatingVars {
        int24 ntl;
        int24 ntu;
        int24 ntlp;
        int24 ntup;
        int24 td;
    }

    function initPool(address recepient) internal returns (IUniswapV3Factory factory) {
        _hevm.deal(recepient, 100e18);

        pool = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        // intialize uniswap contracts
        factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        pool.increaseObservationCardinalityNext(80);
        quote = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

        _hevm.prank(recepient);
        token0.approve(address(router), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(router), type(uint256).max);
    }

    function initBase(address recepient) internal {
        IUniswapV3Factory factory;

        (factory) = initPool(recepient);

        // IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
        //     lpAutomationFee: 0,
        //     strategyCreationFee: 0,
        //     protcolFeeOnManagement: 0,
        //     protcolFeeOnPerformance: 0
        // });

        cltTwap = ICLTTwapQuoter(0xC22E20950aA1f2e91faC75AB7fD8a21eF2C3aB1E);
        cltModules = ICLTModules(0xC203e40Fb4D742a0559705E33C9C2Af41Af2b4dc);

        feeHandler = IGovernanceFeeHandler(0x44Ae07568378d2159ED41D0f060a3d6baefBEb97);

        base = CLTBase(payable(0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6));

        _hevm.prank(recepient);
        token0.approve(address(base), type(uint256).max);
        _hevm.prank(recepient);
        token1.approve(address(base), type(uint256).max);

        modes = Modes(0x69317029384c3305fC04670c68a2b434e2D8C44C);
        rebaseModule = new RebaseModule(recepient, address(base), address(cltTwap), address(quote));

        _hevm.prank(0x4eF03f0eA9e744F22B768E17628cE39a2f48AbE5);
        base.toggleOperator(address(rebaseModule));

        // _hevm.prank(recepient);
        // base.toggleOperator(address(modes));

        // _hevm.prank(recepient);
        // cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(rebaseModule));
        // _hevm.prank(recepient);
        // cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));
        // _hevm.prank(recepient);
        // cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("ACTIVE_REBALANCE"));
        // _hevm.prank(recepient);
        // cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"));
        // _hevm.prank(recepient);
        // cltModules.setNewModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"));
    }

    function createActiveRebalancingAndDeposit(
        address owner,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        int24 lowerDiff,
        int24 upperDiff
    )
        public
        returns (bytes32 strategyID, bytes memory data, ICLTBase.PositionActions memory positionActions)
    {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.DepositParams memory depositParams;

        // // executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        // // executeSwap(token0, token1, pool.fee(), owner, 22e18, 0, 0);

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
        data = abi.encode(lowerDiff, upperDiff, tick, tickLower, tickUpper);
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = data;

        // rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        // rebaseActions[1].data = abi.encode(3);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        _hevm.recordLogs();
        _hevm.prank(owner);
        base.createStrategy(strategyKey, positionActions, 0, 0, false, false);

        Vm.Log[] memory entries = _hevm.getRecordedLogs();
        strategyID = entries[0].topics[1];

        // // console.logBytes32(entries[0].topics[1]);

        // strategyID = 0x5503f260f6a4331fbc621f0652f177b21e5122455388e660e9dd7b16a8e7891f;

        // (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);
        (uint256 am0, uint256 am1) = getAmounts(strategyKey.tickLower, strategyKey.tickUpper, 1e18);

        // console.log(am0);
        // console.log(am1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = am0;
        depositParams.amount1Desired = am1;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;
        _hevm.prank(owner);
        base.deposit(depositParams);
    }

    function getAllTicks(
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
        int24 adl;
        int24 adu;

        (tlp, tup, adl, adu) = rebaseModule.getPreferenceTicks(strategyID, actionName, actionsData);

        if (shouldLog) {
            console.log(convertTickToPrice(tl));
            console.log(convertTickToPrice(tlp));
            console.log(convertTickToPrice(t));
            console.log(convertTickToPrice(tup));
            console.log(convertTickToPrice(tu));
        }
    }

    function convertTickToPrice(int24 tick) public returns (uint256 price) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 numerator2 = 10 ** (token0.decimals() - token1.decimals());
        return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
    }

    function getAmounts(int24 tickLower, int24 tickUpper, uint256 amount0) public returns (uint256, uint256) {
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), amount0
        );

        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
        return (amount0, amount1);
    }

    function executeSwap(
        IERC20 tokenIn,
        IERC20 tokenOut,
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
}
