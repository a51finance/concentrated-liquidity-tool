// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { RebaseFixtures } from "./utils/RebaseFixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { Test } from "forge-std/Test.sol";
import { IQuoter } from "@cryptoalgebra/periphery/contracts/interfaces/IQuoter.sol";
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

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

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

        // uncompounded
        (strategyID, key) = createStrategyAndDepositWithActions(owner, false, 2, 2);

        tickLower = key.tickLower;
        tickUpper = key.tickUpper;

        assertEq(true, checkRange(tickLower, tickUpper));
        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

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

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        _hevm.expectRevert("InvalidCaller");
        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = base.strategies(strategyID);
    }

    function testExecuteStrategyWithInValidStrategyId() public {
        (, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = keccak256(abi.encode(users[1], 1));
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        vm.expectRevert("StrategyIdDonotExist");
        rebaseModule.executeStrategy(executeParams);
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

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

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

        // uncompounded

        (strategyID, key) = createStrategyAndDepositWithActions(owner, true, 2, 2);

        tickLower = key.tickLower;
        tickUpper = key.tickUpper;

        (key,,,,,,,, account) = base.strategies(strategyID);

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

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

    function testExecuteStrategyWithMintFalseSwapFifty() public {
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

        executeSwap(token1, token0, owner, 200e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        (, int24 tick,,,,,) = key.pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, key.pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, key.pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = int256(reserve1 / 2);

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        // Removed 10 token because of slippage
        assertEq(account.balance0 + account.balance1 <= 200 || account.balance0 + account.balance1 >= 190, true);

        // uncompounded

        (strategyID, key) = createStrategyAndDepositWithActions(owner, false, 2, 2);

        tickLower = key.tickLower;
        tickUpper = key.tickUpper;

        (key,,,,,,,, account) = base.strategies(strategyID);

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        executeSwap(token1, token0, owner, 200e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        (, tick,,,,,) = key.pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, key.pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, key.pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = int256(reserve1 / 2);

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        // Removed 10 token because of slippage
        assertEq(account.balance0 + account.balance1 <= 200 || account.balance0 + account.balance1 >= 190, true);
    }

    function testExecuteStrategyWithMintFalseInValidSideMode2() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

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

        // uncompounded

        (strategyID, key) = createStrategyAndDepositWithActions(owner, false, 2, 2);

        tickLower = key.tickLower;
        tickUpper = key.tickUpper;

        (key,,,,,,,, account) = base.strategies(strategyID);
        (, tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

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
        strategyIds[0] = strategyID;
        rebaseModule.executeStrategies(strategyIds);

        (key,,,,,,,, account) = base.strategies(strategyID);

        // since its mode 2 the ticks will roll back
        assertEq(key.tickLower < tick, true);
        assertEq(key.tickUpper < tick, true);
    }

    function testExecuteStrategyWithMintFalseInValidSideMode1Compounded() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;

        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

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

    function testExecuteStrategyWithMintFalseInValidSideMode1Uncompounded() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, false, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;

        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

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

    // shouldMint True and swap amount (changing)

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode2Comp() public {
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

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1 > 0, true);
    }

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode2Uncomp() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, false, 2, 1);

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

        executeSwap(token1, token0, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1 > 0, true);
    }

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode1Comp() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

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

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);
    }

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode1Uncomp() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, false, 1, 1);

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

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);
    }

    function testExecuteStrategyWithMintTrueInValidSideMode2Comp() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        base.getStrategyReserves(strategyID);
        (,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(key.tickLower > tick, true);
        assertEq(key.tickUpper > tick, true);

        console.logInt(key.tickLower);
        console.logInt(key.tickUpper);
        console.logInt(tick);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);
        // now executing executeStrategies()
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyID;
        rebaseModule.executeStrategies(strategyIds);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // since its mode 2 the ticks will roll back
        assertEq(key.tickLower < tick, true);
        assertEq(key.tickUpper < tick, true);

        console.logInt(key.tickLower);
        console.logInt(key.tickUpper);
        console.logInt(tick);

        console.log("res", reserve1, account.balance0, account.balance1);
        assertEq(reserve0, 0);
        // assertEq(reserve1 > 0, true);
    }

    function testExecuteStrategyWithMintTrueInValidSideMode2Uncomp() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, false, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        base.getStrategyReserves(strategyID);
        (,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

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

        console.log(reserve0);
        console.log(reserve1);

        console.log(account.balance0);
        console.log(account.balance1);

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(key.tickLower > tick, true);
        assertEq(key.tickUpper > tick, true);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);

        // now executing executeStrategies()
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyID;
        rebaseModule.executeStrategies(strategyIds);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // since its mode 2 the ticks will roll back
        assertEq(key.tickLower < tick, true);
        assertEq(key.tickUpper < tick, true);

        assertEq(reserve0, 0);
        assertEq(reserve1 > 0, true);

        console.log(account.balance0);
        console.log(account.balance1);
    }

    function testExecuteStrategyWithMintTrueInRangeComp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18 - 1_296_081_497_260_719_881;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        _hevm.prank(owner);
        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - 1_296_081_497_260_719_881 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(strategyKey.tickLower < tick, true);
        assertEq(strategyKey.tickUpper > tick, true);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        (, uint256 liquidityShare,,,,) = base.positions(1);

        _hevm.prank(owner);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[1], refundAsETH: false })
        );

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);
    }

    function testExecuteStrategyWithMintTrueInRangeUncomp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, false, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18 - 1_296_081_497_260_719_881;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        _hevm.prank(owner);
        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - 1_296_081_497_260_719_881 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(strategyKey.tickLower < tick, true);
        assertEq(strategyKey.tickUpper > tick, true);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        (, uint256 liquidityShare,,,,) = base.positions(1);

        _hevm.prank(owner);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[1], refundAsETH: false })
        );

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);
    }

    function testExecuteStrategyWithMintTrueInRangeSwapFiftyComp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = true;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        assertEq(true, checkRange(strategyKey.tickLower, strategyKey.tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(strategyKey.tickLower < tick, true);
        assertEq(strategyKey.tickUpper > tick, true);
    }

    function testExecuteStrategyWithMintTrueInRangeSwapFiftyUncomp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, false, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = true;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        assertEq(true, checkRange(strategyKey.tickLower, strategyKey.tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(strategyKey.tickLower < tick, true);
        assertEq(strategyKey.tickUpper > tick, true);
    }

    function testExecuteStrategyWithMintTrueOutOfRangeSwapFiftyComp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick + 200, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = true;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 2);

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(reserve0 > 0, true);
        assertEq(reserve1 == 0, true);

        (,,,,,,,, account) = base.strategies(strategyID);

        assertEq(account.balance0, 0);
        assertEq(account.balance1 > 0, true);
    }

    function testExecuteStrategyWithMintTrueOutOfRangeSwapFiftyUncomp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, false, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;
        Accounting memory accounting;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick + 200, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = true;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 2);

        rebaseModule.executeStrategy(executeParams);

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(reserve0 > 0, true);
        assertEq(reserve1 == 0, true);

        (,,,,,,,, account) = base.strategies(strategyID);

        assertEq(account.balance0, 0);
        assertEq(account.balance1 > 0, true);
    }

    // MultiConditions

    function testExecuteStrategyWithTwoUsersZeroSwapMintFalseComp() public {
        // deposit user 1
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        console.log("Balance0 before Swap", account.balance0);
        console.log("Balance1 before Swap", account.balance1);
        console.log("Reserve 0 before swap", reserve0);
        console.log("Reserve 1 before swap", reserve1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        base.getStrategyReserves(strategyID);
        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after Swap", account.balance0);
        console.log("Balance1 after Swap", account.balance1);
        console.log("Reserve 0 after swap", reserve0);
        console.log("Reserve 1 after swap", reserve1);
        console.log("Fee0", account.fee0);
        console.log("Fee1", account.fee1);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        base.getStrategyReserves(strategyID);
        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after manual override mint false", account.balance0);
        console.log("Balance1 after manual override mint false", account.balance1);
        console.log("Reserve0 after manual override mint false", reserve0);
        console.log("Reserve1  after manual override mint false", reserve1);
        console.log("Fee0 after manual override mint false", account.fee0);
        console.log("Fee1 after manual override mint false", account.fee1);

        assertEq(reserve1, 0);
        assertEq(reserve0, 0);

        // user 2 deposit in same strategy
        allowNewUser(users[0], owner, 4 ether);

        depoit(strategyID, users[0], 4 ether, 4 ether);

        ICLTBase.Account memory newAccount;
        base.getStrategyReserves(strategyID);
        (key,,,,,,,, newAccount) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after another deposit", newAccount.balance0);
        console.log("Balance1 after another deposit", newAccount.balance1);
        console.log("Reserve0 after another deposit", reserve0);
        console.log("Reserve1  after another deposit", reserve1);
        console.log("Fee0 after another deposit", newAccount.fee0);
        console.log("Fee1 after another deposit", newAccount.fee1);

        assertEq(reserve1, 0);
        assertEq(reserve0, 0);

        assertEq(account.balance0 + 4 ether, newAccount.balance0);
        assertEq(account.balance1 + 4 ether - token1.balanceOf(users[0]), newAccount.balance1);
    }

    function testExecuteStrategyWithTwoUsersZeroSwapMintFalseUncomp() public {
        // deposit user 1
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        console.log("Balance0 before Swap", account.balance0);
        console.log("Balance1 before Swap", account.balance1);
        console.log("Reserve 0 before swap", reserve0);
        console.log("Reserve 1 before swap", reserve1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        base.getStrategyReserves(strategyID);
        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after Swap", account.balance0);
        console.log("Balance1 after Swap", account.balance1);
        console.log("Reserve 0 after swap", reserve0);
        console.log("Reserve 1 after swap", reserve1);
        console.log("Fee0", account.fee0);
        console.log("Fee1", account.fee1);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        base.getStrategyReserves(strategyID);
        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after manual override mint false", account.balance0);
        console.log("Balance1 after manual override mint false", account.balance1);
        console.log("Reserve0 after manual override mint false", reserve0);
        console.log("Reserve1  after manual override mint false", reserve1);
        console.log("Fee0 after manual override mint false", account.fee0);
        console.log("Fee1 after manual override mint false", account.fee1);

        assertEq(reserve1, 0);
        assertEq(reserve0, 0);

        // user 2 deposit in same strategy
        allowNewUser(users[0], owner, 4 ether);

        depoit(strategyID, users[0], 4 ether, 4 ether);

        ICLTBase.Account memory newAccount;
        base.getStrategyReserves(strategyID);
        (key,,,,,,,, newAccount) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0 after another deposit", newAccount.balance0);
        console.log("Balance1 after another deposit", newAccount.balance1);
        console.log("Reserve0 after another deposit", reserve0);
        console.log("Reserve1  after another deposit", reserve1);
        console.log("Fee0 after another deposit", newAccount.fee0);
        console.log("Fee1 after another deposit", newAccount.fee1);

        assertEq(reserve1, 0);
        assertEq(reserve0, 0);

        assertEq(account.balance0 + 4 ether, newAccount.balance0);
        assertEq(account.balance1 + 4 ether - token1.balanceOf(users[0]), newAccount.balance1);
    }

    function testExecuteStrategyWithTwoUsersZeroSwapMintTrueComp() public {
        // deposit user 1
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(account.balance0 == 0, true);
        assertEq(account.balance1 > 0, true);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);

        // user 2 deposit in same strategy
        allowNewUser(users[0], owner, 4 ether);
        uint256 amount0 = 4 ether;
        uint256 amount1 = 4 ether;

        depoit(strategyID, users[0], amount0, amount1);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);

        // generate some fees
        executeSwap(token0, token1, owner, 10e18, 0, 0);
        executeSwap(token1, token0, owner, 10e18, 0, 0);
        executeSwap(token0, token1, owner, 10e18, 0, 0);
        executeSwap(token1, token0, owner, 10e18, 0, 0);

        // user 2 withdraws
        (, uint256 liquidityShare,,,,) = base.positions(2);

        _hevm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 2, liquidity: liquidityShare, recipient: users[0], refundAsETH: false })
        );
    }

    function testExecuteStrategyWithTwoUsersZeroSwapMintTrueUncomp() public {
        // deposit user 1
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, false, 1, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        ICLTBase.Account memory account;
        (key,,,,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.globalState();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(account.balance0 == 0, true);
        assertEq(account.balance1 > 0, true);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);

        // user 2 deposit in same strategy
        allowNewUser(users[0], owner, 4 ether);
        uint256 amount0 = 4 ether;
        uint256 amount1 = 4 ether;

        depoit(strategyID, users[0], amount0, amount1);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve1, 0);
        assertEq(reserve0 > 0, true);

        // generate some fees
        executeSwap(token0, token1, owner, 10e18, 0, 0);
        executeSwap(token1, token0, owner, 10e18, 0, 0);
        executeSwap(token0, token1, owner, 10e18, 0, 0);
        executeSwap(token1, token0, owner, 10e18, 0, 0);

        // user 2 withdraws
        (, uint256 liquidityShare,,,,) = base.positions(2);

        _hevm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 2, liquidity: liquidityShare, recipient: users[0], refundAsETH: false })
        );
    }

    function testExecuteStrategyBeforeBotRebaseingComp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(3);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = false;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);

        rebaseModule.executeStrategy(executeParams);
        bytes memory actionStatus;
        (strategyKey,,, actionStatus,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(strategyKey.tickLower, strategyKey.tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        (, bool exit) = abi.decode(actionStatus, (uint256, bool));
        assertEq(exit, true);

        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = strategyID;

        rebaseModule.executeStrategies(strategies);

        (,,, actionStatus,,,,,) = base.strategies(strategyID);
        (, exit) = abi.decode(actionStatus, (uint256, bool));
        assertEq(exit, false);
    }

    function testExecuteStrategyBeforeBotRebaseingUncomp() public {
        initStrategy(1500);

        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 33);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(3);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, false, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 150e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        int24 tickLower = strategyKey.tickLower;
        int24 tickUpper = strategyKey.tickUpper;

        ICLTBase.Account memory account;

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.globalState();

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.globalState();

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        // inrange ticks provided
        executeParams.tickLower = floorTicks(tick - 500, pool.tickSpacing());
        executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());

        executeParams.shouldMint = false;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);

        rebaseModule.executeStrategy(executeParams);
        bytes memory actionStatus;
        (strategyKey,,, actionStatus,,,,, account) = base.strategies(strategyID);

        assertEq(true, checkRange(strategyKey.tickLower, strategyKey.tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);

        (, bool exit) = abi.decode(actionStatus, (uint256, bool));
        assertEq(exit, true);

        bytes32[] memory strategies = new bytes32[](1);
        strategies[0] = strategyID;

        rebaseModule.executeStrategies(strategies);

        (,,, actionStatus,,,,,) = base.strategies(strategyID);
        (, exit) = abi.decode(actionStatus, (uint256, bool));
        assertEq(exit, false);
    }
}
