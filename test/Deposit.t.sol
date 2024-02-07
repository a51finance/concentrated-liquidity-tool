// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Constants } from "../src/libraries/Constants.sol";
import { FixedPoint128 } from "../src/libraries/FixedPoint128.sol";
import { LiquidityShares } from "../src/libraries/LiquidityShares.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "forge-std/console.sol";

contract DepositTest is Test, Fixtures {
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

    function test_deposit_revertsIfDepositPaused() public {
        bytes32 strategyID = getStrategyID(address(this), 1);
        uint256 depositAmount = 5 ether;

        base.pause();

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        vm.expectRevert("Pausable: paused");
        base.deposit(params);

        base.unpause();
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

    function test_deposit_revertsOnlyOwnerInPrivateStrategy() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, true, true);

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

        assertEq(liquidityShareUser1, depositAmount);
        assertEq(account.totalShares, depositAmount * 2);

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

        assertEq(account.balance0, 360_616_736_599_640);
        assertEq(account.balance1, 0);
        assertEq(account.totalShares, ((depositAmount * 2) + liquidityShareUser2));
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

        assertEq(liquidityShareUser2, 250_968_146_844_201_956);
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

        (, uint256 fee0, uint256 fee1) = base.getStrategyReserves(strategyID1);
        (, uint256 fees0, uint256 fees1) = base.getStrategyReserves(strategyID2);

        console.log("user1 fee earned in strategy1  -> ", fee0, fee1);
        console.log("user2 fee earned in strategy2 -> ", fees0, fees1);
        console.log("total fee of both strategies -> ", fee0 + fees0, fee1 + fees1);

        vm.prank(users[1]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        assertEq(token0.balanceOf(users[1]), fees0 - 1);

        (, fee0, fee1) = base.getStrategyReserves(strategyID1);
        (, fees0, fees1) = base.getStrategyReserves(strategyID2);

        console.log("After user2 claimed fees total fees is now -> ", fee0 + fees0, fee1 + fees1);
    }

    function test_poc_scenerio2() public {
        initPoolAndAddLiquidity();
        initRouter();

        address payable[] memory users = utils.createUsers(2);
        uint256 depositAmount = 5 ether;

        token0.mint(users[0], depositAmount);
        token0.mint(users[1], depositAmount * depositAmount);

        token1.mint(users[0], depositAmount);
        token1.mint(users[1], depositAmount * depositAmount);

        vm.startPrank(users[0]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.startPrank(users[1]);
        token0.approve(address(base), depositAmount * depositAmount);
        token1.approve(address(base), depositAmount * depositAmount);
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

        (, uint256 fee0, uint256 fee1) = base.getStrategyReserves(strategyID1);

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
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 2, refundAsETH: true }));

        (, fee0, fee1) = base.getStrategyReserves(strategyID1);

        console.log("total fees of first strategy is still unctouched -> ", fee0, fee1);

        console.log("user2 unable to claim any amount -> ", token0.balanceOf(msg.sender));
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

        (, uint256 strategy1fee0, uint256 strategy1fee1) = base.getStrategyReserves(getStrategyID(address(this), 1));
        (, uint256 strategy2fee0, uint256 strategy2fee1) = base.getStrategyReserves(getStrategyID(address(this), 2));

        console.log("total fees of both strategies -> ", strategy1fee0 + strategy2fee0, strategy1fee1 + strategy2fee1);

        vm.prank(users[1]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        (, strategy1fee0, strategy1fee1) = base.getStrategyReserves(getStrategyID(address(this), 1));
        (, strategy2fee0, strategy2fee1) = base.getStrategyReserves(getStrategyID(address(this), 2));

        console.log(
            "After user2 claimed total fees is now -> ", strategy1fee0 + strategy2fee0, strategy1fee1 + strategy2fee1
        );

        console.log("user2 successfully claimed only his strategy fees -> ", token0.balanceOf(users[1]));
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
        (, uint256 userShare1,,,,) = base.positions(1);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        (uint256 liquidityUser1,,) = LiquidityShares.calculateShare(depositAmount, depositAmount, 0, 0, 0);

        assertEq(userShare1, liquidityUser1);
        assertEq(account.totalShares, liquidityUser1);

        vm.prank(users[0]);
        base.deposit(params);

        (, uint256 userShare2,,,,) = base.positions(2);
        (,,,,,,,, account) = base.strategies(strategyID);

        assertEq(userShare2, depositAmount);
        assertEq(account.totalShares, depositAmount * 2);

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

        (,,,,,,,, account) = base.strategies(strategyID);

        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        (uint256 liquidityUser3,,) =
            LiquidityShares.calculateShare(depositAmount, depositAmount, reserves0, reserves1, account.totalShares);

        vm.prank(users[1]);
        base.deposit(params);

        (, uint256 userShare3,,,,) = base.positions(3);
        (,,,,,,,, account) = base.strategies(strategyID);

        assertEq(userShare3, liquidityUser3 - 1);
        assertEq(account.totalShares, ((liquidityUser1 * 2) + liquidityUser3) - 1);
    }

    function test_deposit_succeedsWithCorrectFeeGrowth() public {
        initPoolAndAddLiquidity();
        initRouter();

        uint256 depositAmount = 4 ether;

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -200, tickUpper: 200 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, false, false);

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: getStrategyID(address(this), 2),
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit(params);

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

        (, uint256 totalFee0, uint256 totalFee1) = base.getStrategyReserves(getStrategyID(address(this), 2));

        base.deposit(params);

        (,, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,,) = base.positions(2);

        assertEq(feeGrowthInside0LastX128, FullMath.mulDiv(totalFee0, FixedPoint128.Q128, depositAmount));
        assertEq(feeGrowthInside1LastX128, FullMath.mulDiv(totalFee1, FixedPoint128.Q128, depositAmount));
    }

    receive() external payable { }
}
