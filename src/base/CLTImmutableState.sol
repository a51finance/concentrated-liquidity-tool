// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../libraries/TransferHelper.sol";

import "../interfaces/external/IWETH9.sol";
import "../interfaces/ICLTImmutableState.sol";

abstract contract CLTImmutableState is ICLTImmutableState {
    address public immutable override WETH9;
    IUniswapV3Factory public immutable override factory;

    constructor(IUniswapV3Factory _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decodedData = abi.decode(data, (MintCallbackData));

        // verify caller
        address computedPool = factory.getPool(decodedData.token0, decodedData.token1, decodedData.fee);
        require(msg.sender == computedPool, "WHO");

        if (amount0Owed > 0) {
            pay(decodedData.token0, decodedData.payer, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            pay(decodedData.token1, decodedData.payer, msg.sender, amount1Owed);
        }
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(address token, address payer, address recipient, uint256 value) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{ value: value }(); // wrap only what is needed to pay
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }

    /// @dev Amount of token held as unused balance.
    function _balanceOf(address token, address account) internal view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}
