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

        executeSwap(token1, token0, key.pool.fee(), owner, 200e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        (, int24 tick,,,,,) = key.pool.slot0();

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

        (key,,,,,,,, account) = base.strategies(strategyID);

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

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode2() public {
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
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserve0, 0);
        assertEq(reserve1 > 0, true);
    }

    function testExecuteStrategyShouldMintTrueAndSwapZeroMode1() public {
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

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, int24 tick,,,,,) = pool.slot0();

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

    function testExecuteStrategyWithMintTrueInValidSideMode2() public {
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
    }

    function testExecuteStrategyWithMintTrueInRange() public {
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
        Accounting memory accounting;
        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        (, int24 tick,,,,,) = pool.slot0();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        console.log(account.balance0);
        console.log(account.balance1);
        console.log(account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(100e18 - 1_296_081_497_260_719_881 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));

        (, tick,,,,,) = pool.slot0();

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

        console.log(account.balance0);
        console.log(account.balance1);
        console.log(account.uniswapLiquidity);

        (, uint256 liquidityShare,,,,) = base.positions(1);

        _hevm.prank(owner);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[1], refundAsETH: false })
        );

        (strategyKey,,,,,,,, account) = base.strategies(strategyID);
        console.log(account.balance0);
        console.log(account.balance1);

        console.log(token0.balanceOf(users[1]));
    }

    function testExecuteStrategyWithMintTrueInRangeSwapFifty() public {
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
        (, int24 tick,,,,,) = pool.slot0();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.slot0();

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
        console.logInt(tick);
        assertEq(true, checkRange(strategyKey.tickLower, strategyKey.tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        assertEq(strategyKey.tickLower < tick, true);
        assertEq(strategyKey.tickUpper > tick, true);
    }

    function testExecuteStrategyWithMintTrueOutOfRangeSwapFifty() public {
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
        (, int24 tick,,,,,) = pool.slot0();

        accounting.balance0Before = account.balance0;
        accounting.balance1Before = account.balance1;

        assertEq(true, checkRange(tickLower, tickUpper));

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        // 1 wei precision is lost on uniswap
        assertEq(100e18 - reserve0 - 1, account.balance0);
        assertEq(150e18 - reserve1 - 1, account.balance1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(tickLower, tickUpper));
        (reserve0, reserve1) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        (, tick,,,,,) = pool.slot0();

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

    // function testExecuteStrategyWithTwoUsersZeroSwapMintTrue() public {
    //     // deposit user 1
    //     (bytes32 strategyID, ICLTBase.StrategyKey memory key) = createStrategyAndDepositWithActions(owner, true, 1,
    // 1);

    //     int24 tickLower = key.tickLower;
    //     int24 tickUpper = key.tickUpper;

    //     ICLTBase.Account memory account;
    //     (key,,,,,,,, account) = base.strategies(strategyID);

    //     assertEq(true, checkRange(tickLower, tickUpper));

    //     (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

    //     // 1 wei precision is lost on uniswap
    //     assertEq(100e18 - reserve0 - 1, account.balance0);
    //     assertEq(100e18 - reserve1 - 1, account.balance1);

    //     IRebaseStrategy.ExectuteStrategyParams memory executeParams;

    //     executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);

    //     assertEq(false, checkRange(tickLower, tickUpper));

    //     (, int24 tick,,,,,) = pool.slot0();

    //     executeParams.pool = key.pool;
    //     executeParams.strategyID = strategyID;
    //     executeParams.tickLower = floorTicks(tick + 300, pool.tickSpacing());
    //     executeParams.tickUpper = floorTicks(tick + 500, pool.tickSpacing());
    //     executeParams.shouldMint = false;
    //     executeParams.zeroForOne = false;
    //     executeParams.swapAmount = 0;

    //     rebaseModule.executeStrategy(executeParams);

    //     (key,,,,,,,, account) = base.strategies(strategyID);
    //     (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

    //     console.log(account.balance0);
    //     console.log(account.balance1);

    //     assertEq(account.balance0 > 0, true);
    //     assertEq(account.balance1 > 0, true);

    //     assertEq(reserve1, 0);
    //     assertEq(reserve0, 0);

    //     // user 2 deposit in same strategy
    //     uint256 amount0;
    //     uint256 amount1;
    // }
}
