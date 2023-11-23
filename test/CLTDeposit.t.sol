// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Constants } from "../src/libraries/Constants.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "forge-std/console.sol";

contract CLTDepositTest is Test, Fixtures {
    ICLTBase.StrategyKey key;

    event Deposit(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    function setUp() public {
        deployFreshState();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 10e15, true);
        token0.approve(address(base), UINT256_MAX);
        token1.approve(address(base), UINT256_MAX);
    }

    function test_deposit_succeedsWithCorrectShare() public {
        bytes32 strategyID = getStrategyID(address(this), 1);
        uint256 depositAmount = 1 ether;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        vm.expectEmit(true, true, false, true);
        emit Deposit(1, msg.sender, depositAmount, depositAmount, depositAmount);

        base.deposit(params);

        (, uint256 liquidityShare,,,,) = base.positions(1);
        (,,,,, uint256 balance0, uint256 balance1, uint256 shares, uint256 uniswapShare,,) = base.strategies(strategyID);

        assertEq(balance0, 0);
        assertEq(balance1, 0);
        assertEq(shares, depositAmount);
        assertEq(liquidityShare, depositAmount);
        assertEq(uniswapShare, 200_510_416_479_002_803_287);
    }

    function test_deposit_revertsIfZeroAmount() public {
        bytes32 strategyID = getStrategyID(address(this), 1);
        uint256 depositAmount = 0;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        vm.expectRevert(ICLTBase.InvalidShare.selector);
        base.deposit(params);
    }

    function test_deposit_revertsIfMinShare() public {
        bytes32 strategyID = getStrategyID(address(this), 1);
        uint256 depositAmount = Constants.MIN_INITIAL_SHARES - 1;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        vm.expectRevert(ICLTBase.InvalidShare.selector);
        base.deposit(params);
    }

    function test_deposit_succeedsWithNativeToken() public {
        pool = IUniswapV3Pool(factory.createPool(address(weth), address(token1), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 10e15, true);

        bytes32 strategyID = getStrategyID(address(this), 2);
        uint256 depositAmount = 1 ether;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit{ value: depositAmount }(params);
    }

    function test() public { }
}
