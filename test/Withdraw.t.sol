// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "forge-std/console.sol";

contract WithdrawTest is Test, Fixtures {
    Utilities utils;
    ICLTBase.StrategyKey key;

    event Withdraw(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );

    function setUp() public {
        initManagerRoutersAndPoolsWithLiq();
        utils = new Utilities();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, true, false);

        token0.approve(address(base), UINT256_MAX);
        token1.approve(address(base), UINT256_MAX);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );
    }

    function test_withdraw_succeedsWithCorrectShare() public {
        bytes32 strategyId = getStrategyID(address(this), 1);
        uint256 depositAmount = 4 ether;
        address recipient = msg.sender;

        (, uint256 liquidityShare,,,,) = base.positions(1);

        vm.expectEmit(true, true, false, true);
        emit Withdraw(1, recipient, liquidityShare, depositAmount - 1, depositAmount - 1, 0, 0);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare,
                recipient: recipient,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        assertEq(token0.balanceOf(recipient), depositAmount - 1);
        assertEq(token1.balanceOf(recipient), depositAmount - 1);

        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);

        assertEq(account.totalShares, 0);
        assertEq(uint256(account.uniswapLiquidity), 0);
    }

    function test_withdraw_multipleUsers() public {
        address payable[] memory users = utils.createUsers(2);
        uint256 depositAmount = 4 ether;

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

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: getStrategyID(address(this), 1),
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        (, uint256 liquidityShareUser1,,,,) = base.positions(1);

        vm.prank(users[0]);
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

        // update strategy fee
        base.getStrategyReserves(getStrategyID(address(this), 1));

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(getStrategyID(address(this), 1));

        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        uint256 userShare0 = FullMath.mulDiv(account.fee0 + account.balance0 + reserves0, 50, 100);
        uint256 userShare1 = FullMath.mulDiv(account.fee1 + account.balance1 + reserves1, 50, 100);

        vm.prank(users[1]);
        (,, uint256 amount0, uint256 amount1) = base.deposit(params);

        (, uint256 liquidityShareUser3,,,,) = base.positions(3);

        vm.prank(msg.sender);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 3,
                liquidity: liquidityShareUser3,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(msg.sender) + 12, amount0);
        assertEq(token1.balanceOf(msg.sender) + 13, amount1);

        vm.prank(address(this));
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShareUser1,
                recipient: users[0],
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(users[0]) - 5, userShare0);
        assertEq(token1.balanceOf(users[0]) - 6, userShare1);
    }

    function test_withdraw_shouldPayInETH() public {
        pool = IUniswapV3Pool(factory.createPool(address(weth), address(token1), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, true, false);

        address randomUser = utils.getNextUserAddress();
        bytes32 strategyID = getStrategyID(address(this), 2);
        uint256 depositAmount = 15 ether;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit{ value: depositAmount }(params);

        (, uint256 liquidityShare,,,,) = base.positions(2);

        vm.prank(msg.sender);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: liquidityShare,
                recipient: randomUser,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(randomUser.balance + 1, depositAmount);
    }

    function test_withdraw_revertsIfNotOwner() public {
        (, uint256 liquidityShare,,,,) = base.positions(1);

        vm.prank(msg.sender);
        vm.expectRevert();
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_withdraw_revertsIfNoLiquidity() public {
        (, uint256 liquidityShare,,,,) = base.positions(1);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        vm.expectRevert(bytes("NL"));
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_withdraw_revertsIfZeroLiquidityInput() public {
        vm.prank(address(this));
        vm.expectRevert("InvalidShare");
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: 0,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_withdraw_revertsIfBalanceExceed() public {
        (, uint256 liquidityShare,,,,) = base.positions(1);

        vm.prank(address(this));
        vm.expectRevert("InvalidShare");
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare * 10,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_withdraw_succeedsWithCompoundingInExitMode() public {
        address payable[] memory users = utils.createUsers(1);
        bytes32 strategyId = getStrategyID(address(this), 1);
        uint256 depositAmount = 4 ether;

        token0.mint(users[0], depositAmount);
        token1.mint(users[0], depositAmount);

        vm.startPrank(users[0]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyId,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: users[0]
        });

        vm.prank(users[0]);
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

        (uint128 liquidity, uint256 fee0, uint256 fee1) = base.getStrategyReserves(strategyId);
        (uint256 res0, uint256 res1) = getStrategyReserves(key, liquidity);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        uint256 total0 = res0 + account.balance0 + fee0;
        uint256 total1 = res1 + account.balance1 + fee1;

        base.toggleOperator(address(this));

        vm.prank(address(this));

        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: strategyId,
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: abi.encode(1, true),
                sqrtPriceLimitX96: 0
            })
        );

        (liquidity,,) = base.getStrategyReserves(strategyId);
        (res0, res1) = getStrategyReserves(key, liquidity);
        (,,,,,,,, account) = base.strategies(strategyId);

        assertEq(res0, 0);
        assertEq(res1, 0);

        assertEq(account.balance0, total0);
        assertEq(account.balance1, total1);

        (, uint256 liquidityShare,,,,) = base.positions(2);

        vm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(msg.sender), account.balance0 / 2);
        assertEq(token1.balanceOf(msg.sender), account.balance1 / 2);

        (,,,,,,,, account) = base.strategies(strategyId);

        // same amount of shares should be left over in strategy
        assertEq(account.balance0, token0.balanceOf(msg.sender));
        assertEq(account.balance1, token1.balanceOf(msg.sender));
    }

    function test_withdraw_succeedsWithNoCompoundingInExitMode() public {
        address payable[] memory users = utils.createUsers(1);

        // create non-compounding strategy
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        bytes32 strategyId = getStrategyID(address(this), 2);
        uint256 depositAmount = 4 ether;

        token0.mint(users[0], depositAmount);
        token1.mint(users[0], depositAmount);

        vm.startPrank(users[0]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyId,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        vm.prank(address(this));
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: strategyId,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
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

        (uint128 liquidity, uint256 fee0, uint256 fee1) = base.getStrategyReserves(strategyId);
        (uint256 res0, uint256 res1) = getStrategyReserves(key, liquidity);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        uint256 total0 = res0 + account.balance0;
        uint256 total1 = res1 + account.balance1;

        base.toggleOperator(address(this));

        vm.prank(address(this));
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: strategyId,
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: abi.encode(1, true),
                sqrtPriceLimitX96: 0
            })
        );

        (liquidity,,) = base.getStrategyReserves(strategyId);
        (res0, res1) = getStrategyReserves(key, liquidity);
        (,,,,,,,, account) = base.strategies(strategyId);

        assertEq(res0, 0);
        assertEq(res1, 0);

        assertEq(account.balance0, total0);
        assertEq(account.balance1, total1);

        // fee should remain in account
        assertEq(account.fee0, fee0);
        assertEq(account.fee1, fee1);

        vm.prank(users[0]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: depositAmount,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(msg.sender), (account.balance0 + fee0) / 2);
        assertEq(token1.balanceOf(msg.sender), ((account.balance1 + fee1) / 2) - 1);

        (,,,,,,,, account) = base.strategies(strategyId);

        // same amount of shares should be left over in strategy
        assertEq(account.balance0 + account.fee0 - 1, token0.balanceOf(msg.sender));
        assertEq(account.balance1 + account.fee1 - 2, token1.balanceOf(msg.sender));
    }

    function test_withdraw_multipleUsersNoCompounding() public {
        address payable[] memory users = utils.createUsers(3);
        uint256 depositAmount = 4 ether;

        // create non-compounding strategy
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, false, false);

        token0.mint(users[0], depositAmount);
        token0.mint(users[1], depositAmount);
        token0.mint(users[2], depositAmount);

        token1.mint(users[0], depositAmount);
        token1.mint(users[1], depositAmount);
        token1.mint(users[2], depositAmount);

        vm.startPrank(users[0]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.startPrank(users[1]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.startPrank(users[2]);
        token0.approve(address(base), depositAmount);
        token1.approve(address(base), depositAmount);
        vm.stopPrank();

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        vm.prank(users[1]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[1]
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

        // update strategy fee
        base.getStrategyReserves(getStrategyID(address(this), 2));

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(getStrategyID(address(this), 2));

        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        uint256 userShare0 = (account.fee0 + account.balance0 + reserves0) / 2;
        uint256 userShare1 = (account.fee1 + account.balance1 + reserves1) / 2;

        vm.prank(users[2]);
        (,, uint256 amount0, uint256 amount1) = base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[2]
            })
        );

        (, uint256 liquidityShare,,,,) = base.positions(4);

        vm.prank(users[2]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 4,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(msg.sender), amount0 - 1);
        assertEq(token1.balanceOf(msg.sender), amount1 - 2);

        (, liquidityShare,,,,) = base.positions(3);

        vm.prank(users[1]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 3,
                liquidity: liquidityShare,
                recipient: users[1],
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(users[1]), userShare0);
        assertEq(token1.balanceOf(users[1]), userShare1);

        (,,,,,,,, account) = base.strategies(getStrategyID(address(this), 2));

        (reserves0, reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        // contract should have same assets left for last user
        assertEq(account.fee0 + account.balance0 + reserves0, token0.balanceOf(users[1]) + 1);
        assertEq(account.fee1 + account.balance1 + reserves1, token1.balanceOf(users[1]) + 1);
    }

    function test_withdraw_shouldRecieveSingleAssetToken0() public {
        uint256 depositAmount = 5 ether;
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -200, tickUpper: 200 });

        base.createStrategy(key, actions, 0, 0, true, false);

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

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: depositAmount,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        (uint128 liquidity,,) = base.getStrategyReserves(getStrategyID(address(this), 2));
        (uint256 reserves0,) = getStrategyReserves(key, liquidity);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: depositAmount,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: reserves0,
                amount1Min: 0
            })
        );

        assertEq(token0.balanceOf(msg.sender), reserves0);
    }

    function test_withdraw_shouldRecieveSingleAssetToken1() public {
        uint256 depositAmount = 5 ether;
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -200, tickUpper: 200 });

        base.createStrategy(key, actions, 0, 0, true, false);

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

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        (uint128 liquidity,,) = base.getStrategyReserves(getStrategyID(address(this), 2));
        (, uint256 reserves1) = getStrategyReserves(key, liquidity);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: depositAmount,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(token1.balanceOf(msg.sender), reserves1);
    }

    function test_withdraw_shouldPayManagementFee() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        address payable[] memory users = utils.createUsers(1);
        uint256 depositAmount = 4 ether;

        vm.prank(users[0]);
        base.createStrategy(key, actions, 0.1 ether, 0, true, false); // 10% fee on management

        vm.startPrank(address(this));
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(users[0], 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        (, uint256 liquidityShare,,,,) = base.positions(2);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        vm.stopPrank();

        assertEq(token0.balanceOf(msg.sender), depositAmount - (depositAmount * 10) / 100);
        assertEq(token1.balanceOf(msg.sender), depositAmount - (depositAmount * 10) / 100);

        assertEq(token0.balanceOf(users[0]), depositAmount * 10 / 100 - 1);
        assertEq(token1.balanceOf(users[0]), depositAmount * 10 / 100 - 1);
    }

    function test_withdraw_shouldPayPerformanceFee() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        address payable[] memory users = utils.createUsers(1);
        uint256 depositAmount = 4 ether;

        vm.prank(users[0]);
        base.createStrategy(key, actions, 0, 0.1 ether, true, false); // 10% fee on performance

        vm.startPrank(address(this));
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(users[0], 2),
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
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

        (, uint256 liquidityShare,,,,) = base.positions(2);

        (uint128 liquidity, uint256 fee0, uint256 fee1) = base.getStrategyReserves(getStrategyID(users[0], 2));
        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, liquidity);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: liquidityShare,
                recipient: msg.sender,
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        vm.stopPrank();

        assertEq(token0.balanceOf(msg.sender), reserves0 + (fee0 - (fee0 * 10) / 100));
        assertEq(token1.balanceOf(msg.sender), reserves1 + (fee1 - (fee1 * 10) / 100));

        assertEq(token0.balanceOf(users[0]), fee0 * 10 / 100);
        assertEq(token1.balanceOf(users[0]), fee1 * 10 / 100);
    }
}
