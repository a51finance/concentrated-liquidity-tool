// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.5.0;

// import { IUniswapV3MintCallback } from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
// import { IUniswapV3SwapCallback } from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

import { IThrusterMintCallback } from "@thruster-blast/interfaces/callback/IThrusterMintCallback.sol";
import { IThrusterSwapCallback } from "@thruster-blast/interfaces/callback/IThrusterSwapCallback.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
interface ICLTPayments is IThrusterMintCallback, IThrusterSwapCallback {
    struct MintCallbackData {
        address token0;
        address token1;
        uint24 fee;
        address payer;
    }

    struct SwapCallbackData {
        address token0;
        address token1;
        uint24 fee;
    }
}
