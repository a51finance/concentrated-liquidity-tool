// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { Test } from "forge-std/Test.sol";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import { console } from "forge-std/console.sol";

contract ManualOverrideTest is Test, RebaseFixtures {
    address payable[] users;
    address owner;

    struct Accounting {
        uint256 balance0Before;
        uint256 balance1Before;
        uint256 balance0After;
        uint256 balance1After;
    }

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner);
    }

    // Happy path

    function testExecuteStrategyWithValidInputs() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = base.strategies(strategyID);

        assertEq(tickLower != key.tickLower, true);
        assertEq(tickUpper != key.tickUpper, true);
        assertEq(false, checkRange(key.tickLower, key.tickUpper));
    }

    function testExecuteStrategyWithInValidOwner() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        bytes4 selector = bytes4(keccak256("InvalidCaller()"));
        _hevm.expectRevert(selector);
        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = base.strategies(strategyID);
    }

    function testExecuteStrategyWithInValidStrategyId() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = keccak256(abi.encode(users[1], 1));
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        bytes memory encodedError =
            abi.encodeWithSignature("StrategyIdDonotExist(bytes32)", keccak256(abi.encode(users[1], 1)));
        vm.expectRevert(encodedError);
        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = base.strategies(strategyID);
    }

    function testExecuteStrategyWithMintFalseSwapZero() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;
        (key,,,,,,,, account) = base.strategies(strategyID);

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
    }

    // function testExecuteStrategyWithMintFalseSwapFifty() public {
    //     (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2,
    // 1);

    //     int24 tickLower = key.tickLower;
    //     int24 tickUpper = key.tickUpper;

    //     ICLTBase.Account memory account;
    //     Accounting memory accounting;
    //     (key,,,,,,,, account) = base.strategies(strategyID);

    //     accounting.balance0Before = account.balance0;
    //     accounting.balance1Before = account.balance1;

    //     assertEq(true, checkRange(tickLower, tickUpper));

    //     (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

    //     // 1 wei precision is lost on uniswap
    //     assertEq(100e18 - reserve0 - 1, account.balance0);
    //     assertEq(100e18 - reserve1 - 1, account.balance1);

    //     IRebaseStrategy.ExectuteStrategyParams memory executeParams;

    //     executeSwap(token1, token0, key.pool.fee(), owner, 200e18, 0, 0);

    //     assertEq(false, checkRange(tickLower, tickUpper));

    //     (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);
    //     console.log(reserve0, reserve1);
    //     console.log(
    //         "Pool Reserves", token0.balanceOf(address(key.pool)) / 1e18, token1.balanceOf(address(key.pool)) / 1e18
    //     );

    //     (, int24 tick,,,,,) = key.pool.slot0();
    //     // fetch swap amount

    //     executeParams.pool = key.pool;
    //     executeParams.strategyID = strategyID;
    //     executeParams.tickLower = floorTicks(tick - 500, key.pool.tickSpacing());
    //     executeParams.tickUpper = floorTicks(tick - 300, key.pool.tickSpacing());
    //     executeParams.shouldMint = false;
    //     executeParams.zeroForOne = false;
    //     executeParams.swapAmount = 20;

    //     rebaseModule.executeStrategy(executeParams);

    //     // (key,,,,,,,, account) = base.strategies(strategyID);
    //     // (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

    //     // assertEq(reserve0, 0);
    //     // assertEq(reserve1, 0);
    // }

    function testExecuteStrategyWithMintFalseInValidSideMode2() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.slot0();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(key.tickLower > tick, true);
        assertEq(key.tickUpper > tick, true);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        // now executing executeStrategies()
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyID;
        rebaseModule.executeStrategies(strategyIds);

        (key,,,,,,,, account) = base.strategies(strategyID);

        // since its mode 2 the ticks will roll back
        assertEq(key.tickLower < tick, true);
        assertEq(key.tickUpper < tick, true);
    }

    function testExecuteStrategyWithMintFalseInValidSideMode1() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.slot0();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(key.tickLower < tick, true);
        assertEq(key.tickUpper < tick, true);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        // now executing executeStrategies()
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyID;
        rebaseModule.executeStrategies(strategyIds);

        (key,,,,,,,, account) = base.strategies(strategyID);

        // since its mode 2 the ticks will roll back
        assertEq(key.tickLower > tick, true);
        assertEq(key.tickUpper > tick, true);
    }
}
