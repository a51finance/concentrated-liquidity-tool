// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "../libraries/TransferHelper.sol";

import "../interfaces/ICLTPayments.sol";
import "../interfaces/external/IWETH9.sol";

abstract contract CLTPayments is ICLTPayments {
    address public immutable override WETH9;
    IUniswapV3Factory public immutable override factory;

    constructor(IUniswapV3Factory _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }

    receive() external payable { }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decodedData = abi.decode(data, (MintCallbackData));

        // verify caller
        address computedPool = factory.getPool(decodedData.token0, decodedData.token1, decodedData.fee);
        require(msg.sender == computedPool, "WHO");

        if (amount0Owed > 0) {
            TransferHelper.safeTransfer(decodedData.token0, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            TransferHelper.safeTransfer(decodedData.token1, msg.sender, amount1Owed);
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

    function transferFunds(bool refundAsETH, address recipient, address token, uint256 amount) internal {
        if (refundAsETH && token == WETH9) {
            IWETH9(WETH9).withdraw(amount);
            TransferHelper.safeTransferETH(recipient, amount);
        } else {
            TransferHelper.safeTransfer(token, recipient, amount);
        }
    }

    function refundETH() external payable {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    /// @dev Amount of token held as unused balance.
    function _balanceOf(address token, address account) internal view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}
