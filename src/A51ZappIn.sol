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
    error InvalidAmountInput();

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

        _handleTokenOperations(token0, amount0Desired, address(cltBase), useContractBalance0, true, true);
        _handleTokenOperations(token1, amount1Desired, address(cltBase), useContractBalance1, true, true);

        // Call deposit on cltBase
        (tokenId, share, amount0, amount1) = cltBase.deposit(_depositParams);

        // Refund any excess tokens back to msg.sender
        _refundTokens(token0, msg.sender);
        _refundTokens(token1, msg.sender);

        emit ZapInCompleted(msg.sender, tokenId, share, amount0, amount1);
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
        nonReentrancy
        returns (uint256 tokenAmountOut)
    {
        validateSwapInputs(tokenIn, tokenOut, tokenAmountIn, deadline);

        // Transfer tokenIn to the contract
        _handleTokenOperations(tokenIn, tokenAmountIn, address(this), false, true, false);

        // Approve the token amount for the OKX proxy
        _handleTokenOperations(tokenIn, tokenAmountIn, tokenApprover, false, false, true);

        // Execute swap
        (bool success,) = okxProxy.call(swapData);
        if (!success) revert OKXSwapFailed();

        // Check output amount
        tokenAmountOut = tokenOut.balanceOf(address(this));
        if (tokenAmountOut < minAmountOut) revert InsufficientOutput();

        // Transfer output tokens to recipient
        if (recipient != address(this)) {
            _handleTokenOperations(tokenOut, tokenAmountOut, recipient, false, true, false);
        }

        // Refund any excess input tokens
        _refundTokens(tokenIn, refundRecipient);

        return tokenAmountOut;
    }

    function _handleTokenOperations(
        ERC20 token,
        uint256 amountDesired,
        address to,
        bool useBalance,
        bool performTransfer,
        bool performApproval
    )
        private
    {
        if (performTransfer && !useBalance && amountDesired > 0) {
            token.safeTransferFrom(msg.sender, address(this), amountDesired);
        }

        if (performApproval) {
            uint256 currentAllowance = token.allowance(address(this), to);
            if (currentAllowance < amountDesired) {
                if (currentAllowance != 0) {
                    token.safeApprove(to, 0); // Reset only if non-zero to save gas
                }
                token.safeApprove(to, amountDesired);
            }
        }
    }

    function validateSwapInputs(ERC20 tokenIn, ERC20 tokenOut, uint256 tokenAmountIn, uint256 deadline) private view {
        if (tokenIn == tokenOut) revert SameToken();
        if (block.timestamp > deadline) revert PastDeadline();
        if (tokenAmountIn == 0) revert InvalidAmountInput();
    }

    function _refundTokens(ERC20 token, address recepient) private {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(recepient, balance);
        }
    }
}
