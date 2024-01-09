// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Modes } from "../src/modules/rebasing/Modes.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract BasicModes is Test, RebaseFixtures {
    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner);
    }

    function testMode1ValidInputs() public {
        createBasicStrategy(2503, owner, true, 1);

        // user 1
        allowNewUser(users[0], owner, 4 ether);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // user 1 deposit
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        // user 2 deposit
        allowNewUser(users[1], owner, 2 ether);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[1])
            })
        );
        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 1 days);

        assertEq(checkRange(key.tickLower, key.tickUpper), false);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;

        modes.ShiftBase(strategyIDs);
        (key,,,,,,,,) = base.strategies(strategyID);

        (, int24 tick,,,,,) = pool.slot0();

        assertEq(key.tickLower > tick, true);
        assertEq(key.tickUpper > key.tickLower, true);
        assertEq(checkRange(key.tickLower, key.tickUpper), false);
    }

    function testMode2ValidInputs() public {
        createBasicStrategy(2503, owner, true, 2);

        // user 1
        allowNewUser(users[0], owner, 4 ether);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // user 1 deposit
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        // user 2 deposit
        allowNewUser(users[1], owner, 2 ether);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[1])
            })
        );
        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 1 days);

        assertEq(checkRange(key.tickLower, key.tickUpper), false);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;

        modes.ShiftBase(strategyIDs);
        (key,,,,,,,,) = base.strategies(strategyID);

        (, int24 tick,,,,,) = pool.slot0();

        assertEq(key.tickLower < key.tickUpper, true);
        assertEq(key.tickUpper < tick, true);
        assertEq(checkRange(key.tickLower, key.tickUpper), false);
    }

    function testMode3ValidInputs() public {
        createBasicStrategy(122, owner, true, 3);

        // user 1
        allowNewUser(users[0], owner, 4 ether);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // user 1 deposit
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        // user 2 deposit
        allowNewUser(users[1], owner, 2 ether);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[1])
            })
        );
        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 1 days);

        assertEq(checkRange(key.tickLower, key.tickUpper), false);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;

        modes.ShiftBase(strategyIDs);
        (key,,,,,,,,) = base.strategies(strategyID);

        (, int24 tick,,,,,) = pool.slot0();

        assertEq(key.tickLower < key.tickUpper, true);
        assertEq(key.tickUpper < tick, true);
        assertEq(checkRange(key.tickLower, key.tickUpper), false);
    }

    function testVerifyBug() public {
        createBasicStrategy(122, owner, true, 3);

        // user 1
        allowNewUser(users[0], owner, 4 ether);
        allowNewUser(users[1], owner, 4 ether);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // user 1 deposit
        _hevm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        assertEq(token0.balanceOf(users[0]), 0);
        assertEq(token1.balanceOf(users[0]), 0);

        (, uint256 liquidityShare,,,,) = base.positions(1);

        _hevm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[0], refundAsETH: false })
        );

        assertEq(token0.balanceOf(users[0]), 4 ether - 1);
        assertEq(token1.balanceOf(users[0]), 4 ether - 1);

        _hevm.prank(users[0]);
        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 1, amount0Desired: 4 ether - 1, amount1Desired: 4 ether - 1 })
        );

        _hevm.prank(users[1]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[1])
            })
        );

        (, liquidityShare,,,,) = base.positions(1);

        _hevm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[0], refundAsETH: false })
        );

        assertEq(token0.balanceOf(users[0]) > 3 ether, true);
        assertEq(token1.balanceOf(users[0]) > 3 ether, true);

        (, liquidityShare,,,,) = base.positions(2);
        _hevm.prank(users[1]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 2, liquidity: liquidityShare, recipient: users[1], refundAsETH: false })
        );

        // assertEq(token0.balanceOf(users[1]), 4 ether);
        // assertEq(token1.balanceOf(users[1]), 4 ether);
    }

    function testEvent() public {
        createBasicStrategy(2503, owner, true, 1);

        // user 1
        allowNewUser(users[0], owner, 4 ether);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // user 1 deposit
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        executeSwap(token0, token1, pool.fee(), owner, 50e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 20e18, 0, 0);

        // user 2 deposit
        allowNewUser(users[1], owner, 2 ether);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[1])
            })
        );

        executeSwap(token0, token1, pool.fee(), owner, 50e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 20e18, 0, 0);

        (, uint256 liquidityShare,,,,) = base.positions(1);
        _hevm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: users[0], refundAsETH: false })
        );

        // assertEq(checkRange(key.tickLower, key.tickUpper), true);

        // executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        // _hevm.warp(block.timestamp + 1 days);

        // assertEq(checkRange(key.tickLower, key.tickUpper), false);

        // bytes32[] memory strategyIDs = new bytes32[](1);
        // strategyIDs[0] = strategyID;

        // modes.ShiftBase(strategyIDs);
        // (key,,,,,,,,) = base.strategies(strategyID);

        // (, int24 tick,,,,,) = pool.slot0();

        // assertEq(key.tickLower > tick, true);
        // assertEq(key.tickUpper > key.tickLower, true);
        // assertEq(checkRange(key.tickLower, key.tickUpper), false);
    }
}