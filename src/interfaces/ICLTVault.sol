//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

interface ICLTVault {
    struct DepositParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function deposit(DepositParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    event Deposit(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}
