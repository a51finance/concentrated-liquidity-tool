//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import { Multicall } from "./libraries/Multicall.sol";
import { AccessControl } from "./base/AccessControl.sol";
import { ICLTBase } from "./interfaces/ICLTBase.sol";
import { IWETH9 } from "./interfaces/external/IWETH9.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

contract CLTZappIn is Multicall, AccessControl {
    using SafeTransferLib for ERC20;

    /// @notice Error thrown when the same token is used for both input and output
    error SameToken();
    /// @notice Error thrown when the transaction deadline has passed
    error PastDeadline();
    /// @notice Error thrown when the OKX swap fails
    error OKXSwapFailed();
    /// @notice Error thrown when the output amount is insufficient
    error InsufficientOutput();
    /// @notice Error thrown when the input amount is invalid
    error InvalidAmountInput();

    /// @notice Event emitted when a ZapIn operation is completed
    /// @param zapper The address of the user who initiated the ZapIn
    /// @param tokenId The token ID of the liquidity position
    /// @param share The share of the liquidity position
    /// @param amount0 The amount of token0 deposited
    /// @param amount1 The amount of token1 deposited
    event ZapInCompleted(address zapper, uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1);

    /// @notice The OKX proxy contract used for OKX swaps
    address public immutable OKX_PROXY;

    /// @notice The OKX proxy approver contract used for swaps
    address public immutable TOKEN_APPROVER;

    /// @notice CLTBase contract for managing Uniswap v3 liquidity
    ICLTBase private immutable CLT_BASE;

    /// @notice The Wrapped Ethereum contract
    IWETH9 public immutable WETH;

    /// @notice Constructor to initialize the CLTZappIn contract
    /// @param okxProxy The address of the OKX proxy contract
    /// @param cltBase The address of the CLTBase contract
    /// @param tokenApprover The address of the token approver contract
    constructor(address okxProxy, ICLTBase cltBase, address tokenApprover, IWETH9 weth) AccessControl(msg.sender) {
        OKX_PROXY = okxProxy;
        CLT_BASE = cltBase;
        TOKEN_APPROVER = tokenApprover;
        WETH = weth;
    }

    /// @notice Performs a ZapIn operation by depositing tokens into the CLTBase contract
    /// @param depositParams The deposit parameters for the CLTBase contract
    /// @param token0 The first token to deposit
    /// @param token1 The second token to deposit
    /// @param useContractBalance0 Whether to use the contract's balance of token0
    /// @param useContractBalance1 Whether to use the contract's balance of token1
    /// @return tokenId The token ID of the liquidity position
    /// @return share The share of the liquidity position
    /// @return amount0 The amount of token0 deposited
    /// @return amount1 The amount of token1 deposited
    function zapIn(
        ICLTBase.DepositParams memory depositParams,
        ERC20 token0,
        ERC20 token1,
        bool useContractBalance0,
        bool useContractBalance1
    )
        external
        payable
        virtual
        nonReentrancy
        whenNotPaused
        returns (uint256 tokenId, uint256 share, uint256 amount0, uint256 amount1)
    {
        depositParams.amount0Desired = _getDesiredAmount(token0, depositParams.amount0Desired, useContractBalance0);
        depositParams.amount1Desired = _getDesiredAmount(token1, depositParams.amount1Desired, useContractBalance1);

        if (depositParams.amount0Desired != 0) {
            token0.safeApprove(address(CLT_BASE), depositParams.amount0Desired);
        }
        if (depositParams.amount1Desired != 0) {
            token1.safeApprove(address(CLT_BASE), depositParams.amount1Desired);
        }

        // Call deposit on cltBase
        (tokenId, share, amount0, amount1) = CLT_BASE.deposit(depositParams);

        // reset approvals
        if (depositParams.amount0Desired != 0 && token0.allowance(address(this), address(CLT_BASE)) != 0) {
            token0.safeApprove(address(CLT_BASE), 0);
        }
        if (depositParams.amount1Desired != 0 && token1.allowance(address(this), address(CLT_BASE)) != 0) {
            token1.safeApprove(address(CLT_BASE), 0);
        }

        // Refund any excess tokens back to msg.sender
        _refundTokens(token0, msg.sender);
        _refundTokens(token1, msg.sender);

        emit ZapInCompleted(msg.sender, tokenId, share, amount0, amount1);
    }

    /// @notice Determines the desired amount of tokens to be used in the deposit.
    /// @param token The ERC20 token for which the desired amount is calculated.
    /// @param desiredAmount The amount of tokens desired for the deposit.
    /// @param useContractBalance A boolean indicating whether to use the contract's balance of the token.
    /// @return The amount of tokens to be used for the deposit.
    function _getDesiredAmount(
        ERC20 token,
        uint256 desiredAmount,
        bool useContractBalance
    )
        internal
        returns (uint256)
    {
        if (!useContractBalance) {
            if (desiredAmount != 0) {
                _handleTokenOperations(token, desiredAmount, address(this));
            }
        } else {
            desiredAmount = token.balanceOf(address(this));
        }
        return desiredAmount;
    }

    /// @notice Performs a swap using the OKX proxy contract
    /// @param tokenIn The input token for the swap
    /// @param tokenAmountIn The amount of the input token
    /// @param tokenOut The output token for the swap
    /// @param minAmountOut The minimum amount of the output token expected
    /// @param recipient The recipient of the output tokens
    /// @param refundRecipient The recipient of any excess input tokens
    /// @param deadline The deadline by which the swap must complete
    /// @param swapData The swap data for the OKX proxy
    /// @return tokenAmountOut The amount of the output token received
    function doZeroExSwap(
        ERC20 tokenIn,
        uint256 tokenAmountIn,
        ERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        address refundRecipient,
        bool useContractBalance,
        uint256 deadline,
        bytes calldata swapData
    )
        external
        payable
        virtual
        nonReentrancy
        whenNotPaused
        returns (uint256 tokenAmountOut)
    {
        if (tokenIn == tokenOut) revert SameToken();
        if (block.timestamp > deadline) revert PastDeadline();
        if (tokenAmountIn == 0) revert InvalidAmountInput();

        // Transfer tokenIn to the contract
        if (!useContractBalance) {
            _handleTokenOperations(tokenIn, tokenAmountIn, address(this));
        }

        // Approve the token amount for the OKX proxy
        tokenIn.safeApprove(TOKEN_APPROVER, tokenAmountIn);

        // Execute swap
        (bool success,) = OKX_PROXY.call(swapData);
        if (!success) revert OKXSwapFailed();

        // reset approvals
        if (tokenIn.allowance(address(this), address(TOKEN_APPROVER)) != 0) {
            tokenIn.safeApprove(address(TOKEN_APPROVER), 0);
        }

        // check slippage
        tokenAmountOut = tokenOut.balanceOf(address(this));
        if (tokenAmountOut < minAmountOut) revert InsufficientOutput();

        // Transfer output tokens to recipient
        if (recipient != address(this)) {
            _handleTokenOperations(tokenOut, tokenAmountOut, recipient);
        }

        // Refund any excess input tokens
        _refundTokens(tokenIn, refundRecipient);

        return tokenAmountOut;
    }

    /// @notice Wraps the user's ETH input into WETH
    /// @dev Should be used as part of a multicall to convert the user's ETH input into WETH
    /// so that it can be swapped into other tokens.
    function wrapEthInput() external payable {
        WETH.deposit{ value: msg.value }();
    }

    /// @notice Handles token operations such as transfers and approvals
    /// @param _token The token to operate on
    /// @param _amountDesired The desired amount of the token
    /// @param _to The recipient address
    function _handleTokenOperations(ERC20 _token, uint256 _amountDesired, address _to) private {
        if (_amountDesired > 0) {
            _token.safeTransferFrom(msg.sender, _to, _amountDesired);
        }
    }

    /// @notice Refunds any excess tokens back to the recipient
    /// @param _token The token to refund
    /// @param _recipient The recipient of the refund
    function _refundTokens(ERC20 _token, address _recipient) private {
        uint256 balance = _token.balanceOf(address(this));
        if (balance > 0) {
            _token.safeTransfer(_recipient, balance);
        }
    }
}
