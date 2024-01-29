// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { IAlgebraMintCallback } from "@cryptoalgebra/core/contracts/interfaces/callback/IAlgebraMintCallback.sol";
import { IAlgebraSwapCallback } from "@cryptoalgebra/core/contracts/interfaces/callback/IAlgebraSwapCallback.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
interface ICLTPayments is IAlgebraMintCallback, IAlgebraSwapCallback {
    struct MintCallbackData {
        address token0;
        address token1;
        address payer;
    }

    struct SwapCallbackData {
        address token0;
        address token1;
    }
}
