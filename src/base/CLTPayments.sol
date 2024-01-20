// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Constants } from "../libraries/Constants.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { IWETH9 } from "../interfaces/external/IWETH9.sol";
import { ICLTPayments } from "../interfaces/ICLTPayments.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title CLTPayments
/// @notice Contain helper methods for safe token transfers with custom logic
abstract contract CLTPayments is ICLTPayments {
    address private immutable WETH9;
    IUniswapV3Factory private immutable factory;

    constructor(IUniswapV3Factory _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }

    receive() external payable { }

    fallback() external payable { }

    /// @notice Pull in tokens from sender. Called to `msg.sender` after minting liquidity to a position from
    /// IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay to the pool for the minted liquidity.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decodedData = abi.decode(data, (MintCallbackData));

        _verifyCallBack(decodedData.token0, decodedData.token1, decodedData.fee);

        if (amount0Owed > 0) {
            TransferHelper.safeTransfer(decodedData.token0, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            TransferHelper.safeTransfer(decodedData.token1, msg.sender, amount1Owed);
        }
    }

    /// @notice Called to `msg.sender` after minting swaping from IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay to the pool for swap.
    /// @param amount0Delta The amount of token0 due to the pool for the swap
    /// @param amount1Delta The amount of token1 due to the pool for the swap
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));

        _verifyCallBack(decoded.token0, decoded.token1, decoded.fee);

        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(decoded.token0, msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            TransferHelper.safeTransfer(decoded.token1, msg.sender, uint256(amount1Delta));
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

    /// @param refundAsETH Bool value to convert WETH amount into ETH and refund to the recipient held by strategy
    /// @param recipient The entity that will receive payment
    /// @param token The token to pay
    /// @param amount The amount to pay
    function transferFunds(bool refundAsETH, address recipient, address token, uint256 amount) internal {
        if (refundAsETH && token == WETH9) {
            IWETH9(WETH9).withdraw(amount);
            TransferHelper.safeTransferETH(recipient, amount);
        } else {
            TransferHelper.safeTransfer(token, recipient, amount);
        }
    }

    /// @param key A51 strategy key details
    /// @param protcolPercentage The value of percentage to deduct from strategist earned fee
    /// @param percentage The value of percentage to deduct from liquidity or eanrned fee & transfer it to strategist
    /// @param amount0 The amount of token0 from which the strategist fee will deduct
    /// @param amount1 The amount of token1 from which the strategist fee will deduct
    /// @param governance Address of protocol owner
    /// @param strategyOwner Address of strategy owner
    function transferFee(
        ICLTBase.StrategyKey memory key,
        uint256 protcolPercentage,
        uint256 percentage,
        uint256 amount0,
        uint256 amount1,
        address governance,
        address strategyOwner
    )
        internal
        returns (uint256 fee0, uint256 fee1)
    {
        if (percentage > 0) {
            if (amount0 > 0) {
                fee0 = (amount0 * percentage) / Constants.WAD;

                uint256 protcolShare0 = (fee0 * protcolPercentage) / Constants.WAD;

                TransferHelper.safeTransfer(key.pool.token0(), strategyOwner, fee0 - protcolShare0);
                if (protcolShare0 > 0) TransferHelper.safeTransfer(key.pool.token0(), governance, protcolShare0);
            }

            if (amount1 > 0) {
                fee1 = (amount1 * percentage) / Constants.WAD;

                uint256 protcolShare1 = (fee1 * protcolPercentage) / Constants.WAD;

                TransferHelper.safeTransfer(key.pool.token1(), strategyOwner, fee1 - protcolShare1);
                if (protcolShare1 > 0) TransferHelper.safeTransfer(key.pool.token1(), governance, protcolShare1);
            }
        }
    }

    function _verifyCallBack(address token0, address token1, uint24 fee) private view {
        require(msg.sender == factory.getPool(token0, token1, fee));
    }
}
