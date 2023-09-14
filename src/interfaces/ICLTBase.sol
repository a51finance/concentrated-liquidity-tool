//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface ICLTBase {
    struct PoolKey {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
    }

    struct DepositParams {
        PoolKey key;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct WithdrawParams {
        PoolKey key;
        address recipient;
        uint256 userSharePercentage;
    }

    struct ShiftLiquidityParams {
        PoolKey key;
        bool zeroForOne;
        uint256 amount0;
        uint256 amount1;
        uint256 userShare;
        int256 swapAmount;
    }

    struct ClaimFeesParams {
        PoolKey key;
        address recipient;
    }

    error InvalidCaller();
    error TransactionTooAged();

    function deposit(DepositParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    event Deposit(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}
