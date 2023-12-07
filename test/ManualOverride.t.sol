// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract ManualOverrideTest is Test, RebaseFixtures {
    IUniswapV3Pool private poolContract;
    CLTBase private baseContract;

    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        (baseContract, poolContract) = initBase(owner);
    }

    // Happy path

    function testExecuteStrategyWithValidInputs() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) =
            createStrategyAndDepositWithActions(baseContract, poolContract, owner, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(poolContract, tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, poolContract.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(poolContract, tickLower, tickUpper));

        (, int24 tick,,,,,) = poolContract.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, poolContract.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, poolContract.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = baseContract.strategies(strategyID);

        assertEq(tickLower != key.tickLower, true);
        assertEq(tickUpper != key.tickUpper, true);
        assertEq(false, checkRange(poolContract, key.tickLower, key.tickUpper));
    }

    function testExecuteStrategyWithInValidOwner() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) =
            createStrategyAndDepositWithActions(baseContract, poolContract, owner, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(poolContract, tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, poolContract.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(poolContract, tickLower, tickUpper));

        (, int24 tick,,,,,) = poolContract.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = floorTicks(tick - 500, poolContract.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, poolContract.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        bytes4 selector = bytes4(keccak256("InvalidCaller()"));
        _hevm.expectRevert(selector);
        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = baseContract.strategies(strategyID);
    }

    function testExecuteStrategyWithInValidStrategyId() public {
        (bytes32 strategyID, ICLTBase.StrategyKey memory key) =
            createStrategyAndDepositWithActions(baseContract, poolContract, owner, 2, 1);

        int24 tickLower = key.tickLower;
        int24 tickUpper = key.tickUpper;

        assertEq(true, checkRange(poolContract, tickLower, tickUpper));

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeSwap(token1, token0, poolContract.fee(), owner, 500e18, 0, 0);

        assertEq(false, checkRange(poolContract, tickLower, tickUpper));

        (, int24 tick,,,,,) = poolContract.slot0();

        executeParams.pool = key.pool;
        executeParams.strategyID = keccak256(abi.encode(users[1], 1));
        executeParams.tickLower = floorTicks(tick - 500, poolContract.tickSpacing());
        executeParams.tickUpper = floorTicks(tick - 300, poolContract.tickSpacing());
        executeParams.shouldMint = true;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        _hevm.prank(users[0]);
        bytes memory encodedError =
            abi.encodeWithSignature("StrategyIdDonotExist(bytes32)", keccak256(abi.encode(users[1], 1)));
        vm.expectRevert(encodedError);
        rebaseModule.executeStrategy(executeParams);
        (key,,,,,,,,) = baseContract.strategies(strategyID);
    }
}
