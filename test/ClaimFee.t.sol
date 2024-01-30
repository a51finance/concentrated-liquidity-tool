// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Constants } from "../src/libraries/Constants.sol";

import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TickMath } from "@cryptoalgebra/core/contracts/libraries/TickMath.sol";
import { IAlgebraPool } from "@cryptoalgebra/core/contracts/interfaces/IAlgebraPool.sol";
import { ISwapRouter } from "@cryptoalgebra/periphery/contracts/interfaces/ISwapRouter.sol";

import "forge-std/console.sol";

contract ClaimFeeTest is Test, Fixtures {
    Utilities utils;
    ICLTBase.StrategyKey key;

    function setUp() public {
        initManagerRoutersAndPoolsWithLiq();
        utils = new Utilities();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        base.createStrategy(key, actions, 0, 0, false, false);

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

    function test_claimFee_revertsIfCompounder() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, true, false);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        // earn fee
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        vm.expectRevert("onlyNonCompounders");
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 2, refundAsETH: true }));
    }

    function test_claimFee_revertsIfNoLiquidity() public {
        base.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 1, liquidity: 4 ether, recipient: msg.sender, refundAsETH: true })
        );

        vm.expectRevert("NoLiquidity");
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 1, refundAsETH: true }));
    }

    function test_claimFee_feeShare() public {
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        // this user shouldn't earn any fee
        uint256 user1Deposit = 4 ether;
        address payable[] memory users = utils.createUsers(1);

        token0.mint(users[0], user1Deposit);
        token1.mint(users[0], user1Deposit);

        vm.startPrank(users[0]);
        token0.approve(address(base), user1Deposit);
        token1.approve(address(base), user1Deposit);
        vm.stopPrank();

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: user1Deposit,
                amount1Desired: user1Deposit,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(getStrategyID(address(this), 1));

        vm.startPrank(address(this));
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 1, refundAsETH: true }));

        assertEq(token0.balanceOf(msg.sender), account.fee0);
        assertEq(token1.balanceOf(msg.sender), account.fee1);
    }

    function test_claimFee_multipleUserShare() public {
        address payable[] memory users = utils.createUsers(3);

        uint256 user1Deposit = 12 ether;

        token0.mint(users[0], user1Deposit);
        token1.mint(users[0], user1Deposit);

        vm.startPrank(users[0]);
        token0.approve(address(base), user1Deposit);
        token1.approve(address(base), user1Deposit);
        vm.stopPrank();

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: user1Deposit,
                amount1Desired: user1Deposit,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        (, uint256 fee0,) = base.getStrategyReserves(getStrategyID(address(this), 1));

        // nft 1 earns 25% of fees
        vm.startPrank(address(this));
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 1, refundAsETH: true }));

        // nft 2 earns 75% of fees
        vm.startPrank(users[0]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[2], tokenId: 2, refundAsETH: true }));

        assertEq(token0.balanceOf(users[1]), fee0 * 25 / 100);
        assertEq(token0.balanceOf(users[2]), fee0 * 75 / 100);
    }

    function test_claimFee_multipleUsersWithDifferentFeeGrowth() public {
        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        uint256 user1Deposit = 4 ether;
        address payable[] memory users = utils.createUsers(3);

        token0.mint(users[0], user1Deposit + user1Deposit);
        token1.mint(users[0], user1Deposit + user1Deposit);

        vm.startPrank(users[0]);
        token0.approve(address(base), user1Deposit + user1Deposit);
        token1.approve(address(base), user1Deposit + user1Deposit);
        vm.stopPrank();

        vm.prank(users[0]);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: user1Deposit,
                amount1Desired: user1Deposit,
                amount0Min: 0,
                amount1Min: 0,
                recipient: users[0]
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        vm.startPrank(address(this));
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 1, refundAsETH: true }));

        /// user1 has earned more fees which is 66% which is fishy because for token1 both have equal share & growth
        assertEq(token0.balanceOf(msg.sender), 4_416_689_949_339_070);
        assertEq(token1.balanceOf(msg.sender), 2_393_644_397_049_624);

        vm.startPrank(users[0]);
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: users[1], tokenId: 2, refundAsETH: true }));

        /// user2 has earned 33% of token1
        assertEq(token0.balanceOf(users[1]), 603_895_394_819_763);
        assertEq(token1.balanceOf(users[1]), 600_879_131_409_738);
    }

    function test_claimFee_shouldPayStrategistFee() public {
        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        address payable[] memory users = utils.createUsers(1);

        vm.prank(users[0]);
        base.createStrategy(key, actions, 0, 100_000_000_000_000_000, false, false); // 10% share of strategist

        vm.startPrank(address(this));
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(users[0], 2),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        (uint256 fee0, uint256 fee1) = base.getUserfee(2);

        (, address strategyOwner,,,,,, uint256 performanceFee,) = base.strategies(getStrategyID(users[0], 2));

        uint256 strategyOwnerShare0 = (fee0 * performanceFee) / Constants.WAD;
        uint256 strategyOwnerShare1 = (fee1 * performanceFee) / Constants.WAD;

        fee0 -= strategyOwnerShare0;
        fee1 -= strategyOwnerShare1;

        vm.startPrank(address(this));
        base.claimPositionFee(ICLTBase.ClaimFeesParams({ recipient: msg.sender, tokenId: 2, refundAsETH: true }));

        assertEq(token0.balanceOf(msg.sender), fee0);
        assertEq(token1.balanceOf(msg.sender), fee1);

        assertEq(token0.balanceOf(strategyOwner), strategyOwnerShare0);
        assertEq(token1.balanceOf(strategyOwner), strategyOwnerShare1);
    }

    function test_claimFee_shouldPayProtocolFee() public { }

    function test_claimFee() public { }
}
