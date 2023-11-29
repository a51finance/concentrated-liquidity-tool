// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Constants } from "../src/libraries/Constants.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "forge-std/console.sol";

contract CLTDepositTest is Test, Fixtures {
    Utilities utils;
    ICLTBase.StrategyKey key;

    event Deposit(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    function setUp() public {
        deployFreshState();
        utils = new Utilities();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 10e15, true, false);
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
        (,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);
        assertEq(account.totalShares, depositAmount);
        assertEq(base.balanceOf(msg.sender), 1);
        assertEq(liquidityShare, depositAmount);
        assertEq(account.uniswapLiquidity, 200_510_416_479_002_803_287);
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

        base.createStrategy(key, actions, 10e15, true, false);

        bytes32 strategyID = getStrategyID(address(this), 2);
        uint256 depositAmount = 3 ether;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit{ value: depositAmount }(params);

        (, uint256 liquidityShare,,,,) = base.positions(1);
        (,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.totalShares, depositAmount);
        assertEq(liquidityShare, depositAmount);
        assertEq(account.uniswapLiquidity, 601_531_249_437_008_409_863);
    }

    function test_deposit_revertsWithInSufficientFunds() public {
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

        vm.prank(msg.sender);
        vm.expectRevert();
        base.deposit(params);
    }

    function test_deposit_multipleUsers() public {
        address payable[] memory users = utils.createUsers(2);
        uint256 depositAmount = 5 ether;

        token0.mint(users[0], depositAmount);
        token0.mint(users[1], depositAmount);

        token1.mint(users[0], depositAmount);
        token1.mint(users[1], depositAmount);

        vm.startPrank(users[0]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.startPrank(users[1]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        bytes32 strategyID = getStrategyID(address(this), 1);

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit(params);

        vm.prank(users[0]);
        base.deposit(params);

        (, uint256 liquidityShareUser1,,,,) = base.positions(2);
        (,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.totalShares, (depositAmount * 2) + 1);
        assertEq(liquidityShareUser1, depositAmount + 1);

        /// try swapping here to check contract balances || approval needed
        // router.exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: address(token0),
        //         tokenOut: address(token1),
        //         fee: 500,
        //         recipient: address(this),
        //         deadline: block.timestamp + 1 days,
        //         amountIn: 1 ether,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );

        // (, int24 t,,,,,) = pool.slot0();
        // console.logInt(t);

        vm.prank(users[1]);
        base.deposit(params);

        (, uint256 liquidityShareUser2,,,,) = base.positions(3);
        (,,,,,, account) = base.strategies(strategyID);

        assertEq(account.totalShares, (depositAmount * 3) + 2);
        assertEq(liquidityShareUser2, depositAmount + 1);
    }

    function test_deposit_succeedsOutOfRangeDeposit() public {
        initPoolAndAddLiquidity();
        initRouter();

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

        base.deposit(params);

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        base.deposit(params);

        (, uint256 liquidityShareUser2,,,,) = base.positions(2);
        (,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log(liquidityShareUser2, account.totalShares, account.uniswapLiquidity);
        console.log(account.balance0, account.balance1);
    }

    function test_deposit_shouldReturnExtraETH() public { }

    function test_deposit() public { }
}
