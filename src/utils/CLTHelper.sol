// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.20;

import "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import "@cryptoalgebra/integral-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../interfaces/ICLTBase.sol";
import "../libraries/LiquidityShares.sol";

contract CLTHelper {
    function decodePositionActions(bytes memory actions) external pure returns (ICLTBase.PositionActions memory) {
        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));
        return modules;
    }

    function decodeActionStatus(bytes memory actionStatus)
        external
        pure
        returns (uint256 rebaseCount, bool isExit, uint256 lastUpdateTimeStamp, uint256 manualSwapsCount)
    {
        if (actionStatus.length > 0) {
            if (actionStatus.length == 64) {
                (rebaseCount, isExit) = abi.decode(actionStatus, (uint256, bool));
            } else {
                (rebaseCount, isExit, lastUpdateTimeStamp, manualSwapsCount) =
                    abi.decode(actionStatus, (uint256, bool, uint256, uint256));
            }
        }
    }

    function getStrategyReserves(
        address poolAddress,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityAmount
    )
        external
        view
        returns (uint256 reserves0, uint256 reserves1)
    {
        (uint160 sqrtPriceX96,,,,,) = IAlgebraPool(poolAddress).globalState();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (liquidityAmount > 0) {
            (reserves0, reserves1) =
                LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidityAmount);
        }
    }

    function previewDeposit(
        ICLTBase cltBase,
        bytes32 strategyId,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        (ICLTBase.StrategyKey memory key,,,, bool isCompound,,,, ICLTBase.Account memory account) =
            cltBase.strategies(strategyId);

        // update reserves & strategy fee
        (uint128 liquidity, uint256 fee0, uint256 fee1) = cltBase.getStrategyReserves(strategyId);
        (uint256 reserve0, uint256 reserve1) = PoolActions.getAmountsForLiquidity(key, liquidity);

        if (isCompound) {
            reserve0 += fee0;
            reserve1 += fee1;
        }

        // includes unused balance
        reserve0 += account.balance0;
        reserve1 += account.balance1;

        // If total supply > 0, strategy can't be empty
        assert(account.totalShares == 0 || reserve0 != 0 || reserve1 != 0);

        (shares, amount0, amount1) =
            LiquidityShares.calculateShare(amount0Desired, amount1Desired, reserve0, reserve1, account.totalShares);
    }

    function previewWithdraw(
        ICLTBase cltBase,
        uint256 tokenId,
        uint256 liquidity
    )
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (bytes32 strategyId, uint256 liquidityShare,,,,) = cltBase.positions(tokenId);

        // update strategy fee
        cltBase.getStrategyReserves(strategyId);

        // fetch updated fee
        (
            ICLTBase.StrategyKey memory key,
            ,
            ,
            ,
            bool isCompound,
            ,
            uint256 managementFee,
            uint256 performanceFee,
            ICLTBase.Account memory account
        ) = cltBase.strategies(strategyId);

        if (account.uniswapLiquidity > 0) {
            (amount0, amount1,,) = PoolActions.burnLiquidity(
                key, uint128(FullMath.mulDiv(account.uniswapLiquidity, liquidity, account.totalShares))
            );
        }

        uint256 fee0;
        uint256 fee1;

        if (!isCompound) {
            (fee0, fee1) = IBase(address(cltBase)).getUserfee(tokenId);
        } else {
            (fee0, fee1) = (
                FullMath.mulDiv(account.fee0, liquidityShare, account.totalShares),
                FullMath.mulDiv(account.fee1, liquidityShare, account.totalShares)
            );
        }

        if (performanceFee > 0) {
            fee0 -= FullMath.mulDiv(fee0, performanceFee, 1e18);
            fee1 -= FullMath.mulDiv(fee1, performanceFee, 1e18);
        }

        if (managementFee > 0) {
            amount0 -= FullMath.mulDiv(amount0, managementFee, 1e18);
            amount1 -= FullMath.mulDiv(amount1, managementFee, 1e18);
        }

        // should calculate correct amounts for both compounders & non-compounders
        amount0 += FullMath.mulDiv(account.balance0, liquidity, account.totalShares) + fee0;
        amount1 += FullMath.mulDiv(account.balance1, liquidity, account.totalShares) + fee1;
    }
}

interface IBase {
    function getUserfee(uint256 tokenId) external returns (uint256 fee0, uint256 fee1);
}
