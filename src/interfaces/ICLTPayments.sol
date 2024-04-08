// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.5.0;

import { IPancakeV3MintCallback } from "@pancakeswap/v3-core/contracts/interfaces/callback/IPancakeV3MintCallback.sol";
import { IPancakeV3SwapCallback } from "@pancakeswap/v3-core/contracts/interfaces/callback/IPancakeV3SwapCallback.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
interface ICLTPayments is IPancakeV3MintCallback, IPancakeV3SwapCallback {
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
