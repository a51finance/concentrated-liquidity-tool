// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import { RebaseFixtures } from "./utils/RebaseFixtures.sol";
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

    function testShiftBaseInvalidID() public {
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

        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 1 days);

        assertEq(checkRange(key.tickLower, key.tickUpper), false);

        bytes32[] memory strategyIDs = new bytes32[](2);
        strategyIDs[0] = getStrategyID(address(this), 1);
        strategyIDs[1] = getStrategyID(address(this), 2);

        for (uint256 i = 0; i < strategyIDs.length; i++) {
            bytes32[] memory _strategyIDs = new bytes32[](1);

            (key,,,,,,,,) = base.strategies(strategyIDs[i]);
            if (address(key.pool) == address(0)) {
                _strategyIDs[0] = strategyIDs[i];
                bytes memory encodedError =
                    abi.encodeWithSignature("InvalidStrategyId(bytes32)", keccak256(abi.encode(address(this), 2)));
                vm.expectRevert(encodedError);
                modes.ShiftBase(_strategyIDs);
            } else {
                _strategyIDs[0] = strategyIDs[i];
                modes.ShiftBase(_strategyIDs);
            }
        }
    }

    function testCompleteShiftBase() public {
        // Deposit for all
        createBasicStrategy(2503, owner, true, 1);
        createBasicStrategy(3223, owner, false, 2);
        createBasicStrategy(3343, owner, false, 3);
        createBasicStrategy(1232, owner, true, 4);

        // user 1
        allowNewUser(users[0], owner, 10 ether);

        (ICLTBase.StrategyKey memory key1,,,,,,,,) = base.strategies(getStrategyID(address(this), 1));
        (ICLTBase.StrategyKey memory key2,,,,,,,,) = base.strategies(getStrategyID(address(this), 2));
        (ICLTBase.StrategyKey memory key3,,,,,,,,) = base.strategies(getStrategyID(address(this), 3));
        (ICLTBase.StrategyKey memory key4,,,,,,,,) = base.strategies(getStrategyID(address(this), 4));

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 3),
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 4),
                amount0Desired: 2 ether,
                amount1Desired: 2 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(users[0])
            })
        );

        assertEq(checkRange(key1.tickLower, key1.tickUpper), true);
        assertEq(checkRange(key2.tickLower, key2.tickUpper), true);
        assertEq(checkRange(key3.tickLower, key3.tickUpper), true);
        assertEq(checkRange(key4.tickLower, key4.tickUpper), true);

        bytes32[] memory strategyIDs = new bytes32[](4);
        strategyIDs[0] = getStrategyID(address(this), 1);
        strategyIDs[1] = getStrategyID(address(this), 2);
        strategyIDs[2] = getStrategyID(address(this), 3);
        strategyIDs[3] = getStrategyID(address(this), 4);

        uint256 strategyIdsLength = strategyIDs.length;
        ICLTBase.PositionActions memory modules;
        ICLTBase.StrategyKey memory key;
        bytes memory actions;

        for (uint256 i = 0; i < strategyIdsLength; i++) {
            bytes32[] memory _strategyIDs = new bytes32[](1);
            (key,, actions,,,,,,) = base.strategies(strategyIDs[i]);
            modules = abi.decode(actions, (ICLTBase.PositionActions));

            if (modules.mode == 1) {
                executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
                _hevm.warp(block.timestamp + 1 days);
                (key,,,,,,,,) = base.strategies(strategyIDs[0]);
                assertEq(checkRange(key.tickLower, key.tickUpper), false);
                _strategyIDs[0] = strategyIDs[0];
                modes.ShiftBase(_strategyIDs);
            } else if (modules.mode == 2) {
                executeSwap(token1, token0, pool.fee(), owner, 1000e18, 0, 0);
                _hevm.warp(block.timestamp + 1 days);
                (key,,,,,,,,) = base.strategies(strategyIDs[1]);
                assertEq(checkRange(key.tickLower, key.tickUpper), false);
                _strategyIDs[0] = strategyIDs[1];
                modes.ShiftBase(_strategyIDs);
            } else if (modules.mode == 3) {
                executeSwap(token1, token0, pool.fee(), owner, 1000e18, 0, 0);
                _hevm.warp(block.timestamp + 1 days);
                (key,,,,,,,,) = base.strategies(strategyIDs[2]);
                assertEq(checkRange(key.tickLower, key.tickUpper), false);
                _strategyIDs[0] = strategyIDs[2];
                modes.ShiftBase(_strategyIDs);
            } else {
                _strategyIDs[0] = strategyIDs[3];
                bytes memory encodedError = abi.encodeWithSignature("InvalidModeId(uint256)", 4);
                vm.expectRevert(encodedError);
                modes.ShiftBase(_strategyIDs);
            }
        }
    }
}
