//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import { Multicall } from "./libraries/Multicall.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ICLTBase } from "./interfaces/ICLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { AccessControl } from "./base/AccessControl.sol";

contract A51ZappIn is Multicall, AccessControl {
    using SafeTransferLib for ERC20;

    error SameToken();
    error PastDeadline();
    error OKXSwapFailed();
    error InsufficientOutput();

    event ZapInCompleted(address zapper, uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1);

    /// @notice The OKX proxy contract used for OKX swaps
    address public okxProxy;

    /// @notice The OKX proxy approver contract used for swaps
    address public tokenApprover;

    /// @notice CLTBase contract for managing Uniswap v3 liquidity
    ICLTBase private immutable cltBase;

    constructor(address _okxProxy, ICLTBase _cltBase, address _tokenApprover) AccessControl(msg.sender) {
        okxProxy = _okxProxy;
        cltBase = _cltBase;
        tokenApprover = _tokenApprover;
    }

    function zapIn(
        ICLTBase.DepositParams memory _depositParams,
        ERC20 token0,
        ERC20 token1,
        bool useContractBalance0,
        bool useContractBalance1
    )
        external
        payable
        virtual
        nonReentrancy
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
        uint256 amount0Desired = useContractBalance0 ? token0.balanceOf(address(this)) : _depositParams.amount0Desired;
        uint256 amount1Desired = useContractBalance1 ? token1.balanceOf(address(this)) : _depositParams.amount1Desired;

        _handleTokenOperations(token0, amount0Desired, address(cltBase), useContractBalance0);
        _handleTokenOperations(token1, amount1Desired, address(cltBase), useContractBalance1);

        // Call deposit on cltBase
        (tokenId, share, amount0, amount1) = cltBase.deposit(_depositParams);

        // Refund any excess tokens back to msg.sender
        _refundTokens(token0);
        _refundTokens(token1);

        emit ZapInCompleted(msg.sender, tokenId, share, amount0, amount1);
    }

    function _handleTokenOperations(ERC20 token, uint256 amountDesired, address to, bool useBalance) private {
        if (!useBalance && amountDesired > 0) {
            token.safeTransferFrom(msg.sender, address(this), amountDesired);
        }
        uint256 currentAllowance = token.allowance(address(this), to);
        if (currentAllowance < amountDesired) {
            token.safeApprove(to, 0); // Reset approval to 0 first to comply with ERC20 standard
            token.safeApprove(to, amountDesired);
        }
    }

    function _refundTokens(ERC20 token) private {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(msg.sender, balance);
        }
    }

    function doZeroExSwap(
        ERC20 tokenIn,
        uint256 tokenAmountIn,
        ERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        address refundRecipient,
        uint256 deadline,
        bytes calldata swapData
    )
        external
        payable
        virtual
        returns (uint256 tokenAmountOut)
    {
        if (tokenIn == tokenOut) revert SameToken();
        if (block.timestamp > deadline) revert PastDeadline();

        if (tokenAmountIn > 0) {
            tokenIn.safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        }

        // Approve okxProxy to spend tokens if necessary
        tokenIn.safeApprove(tokenApprover, tokenAmountIn);

        // Execute swap
        (bool success,) = okxProxy.call(swapData);
        if (!success) revert OKXSwapFailed();

        // Reset approval for security reasons
        if (tokenIn.allowance(address(this), address(tokenApprover)) != 0) {
            tokenIn.safeApprove(address(tokenApprover), 0);
        }

        // Check output amount
        tokenAmountOut = tokenOut.balanceOf(address(this));
        if (tokenAmountOut < minAmountOut) revert InsufficientOutput();

        // Transfer output tokens to recipient
        if (recipient != address(this)) {
            tokenOut.safeTransfer(recipient, tokenAmountOut);
        }

        // Refund any excess input tokens
        uint256 balance = tokenIn.balanceOf(address(this));
        if (balance > 0) {
            tokenIn.safeTransfer(refundRecipient, balance);
        }

        return tokenAmountOut;
    }
}
