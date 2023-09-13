// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

library Position {
    struct Data {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }
}
