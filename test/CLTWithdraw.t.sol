// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "forge-std/console.sol";

contract CLTWithdrawTest is Test, Fixtures {
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
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: recipient, refundAsETH: true })
        );

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        assertEq(token0.balanceOf(recipient), depositAmount - 1);
        assertEq(token1.balanceOf(recipient), depositAmount - 1);

        assertEq(account.balance0, 0);
        assertEq(account.balance1, 0);

        assertEq(account.totalShares, 0);
        assertEq(account.uniswapLiquidity, 0);
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
                refundAsETH: true
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
                refundAsETH: true
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
            ICLTBase.WithdrawParams({ tokenId: 2, liquidity: liquidityShare, recipient: randomUser, refundAsETH: true })
        );

        assertEq(randomUser.balance + 1, depositAmount);
    }

    function test_withdraw_revertsIfNotOwner() public {
        (, uint256 liquidityShare,,,,) = base.positions(1);

        vm.prank(msg.sender);
        vm.expectRevert();
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: liquidityShare, recipient: msg.sender, refundAsETH: true })
        );
    }

    function test_withdraw_revertsIfZeroLiquidity() public {
        vm.prank(address(this));
        vm.expectRevert(ICLTBase.InvalidShare.selector);
        base.withdraw(ICLTBase.WithdrawParams({ tokenId: 1, liquidity: 0, recipient: msg.sender, refundAsETH: true }));
    }

    function test_withdraw_revertsIfBalanceExceed() public {
        (, uint256 liquidityShare,,,,) = base.positions(1);

        vm.prank(address(this));
        vm.expectRevert(ICLTBase.InvalidShare.selector);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: liquidityShare * 10,
                recipient: msg.sender,
                refundAsETH: true
            })
        );
    }

    function test_withdraw_() public { }
}
