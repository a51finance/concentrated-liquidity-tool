// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTBase.sol";

import "./base/CLTImmutableState.sol";

import "./libraries/Position.sol";
import "./libraries/PoolActions.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTBase is ICLTBase, CLTImmutableState, ERC721 {
    using PoolActions for IUniswapV3Pool;

    uint256 private _nextId = 1;

    mapping(uint256 => Position.Data) private positions;
    mapping(address => bool) private _operatorApproved;

    modifier onlyOperator() {
        require(_operatorApproved[msg.sender]);
        _;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp >= deadline) revert TransactionTooAged();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _weth9,
        IUniswapV3Factory _factory
    )
        ERC721(_name, _symbol)
        CLTImmutableState(_factory, _weth9)
    { }

    function deposit(DepositParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (liquidity, amount0, amount1) = params.key.pool.mintLiquidity(
            params.key.tickLower, params.key.tickUpper, params.amount0Desired, params.amount1Desired
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "HOW");

        _mint(params.recipient, (tokenId = _nextId++));

        positions[tokenId] =
            Position.Data({ tickLower: params.key.tickLower, tickUpper: params.key.tickUpper, liquidity: liquidity });

        emit Deposit(tokenId, liquidity, amount0, amount1);
    }

    function withdraw() external { }

    function claim(ClaimFeesParams calldata params) external {
        params.key.pool.collectPendingFees(params.recipient, params.key.tickLower, params.key.tickUpper);
    }

    function shiftLiquidity(ShiftLiquidityParams calldata params) external {
        // checks
        PoolActions.checkRange(params.key.tickLower, params.key.tickUpper, 60);

        params.key.pool.burnUserLiquidity(params.key.tickLower, params.key.tickUpper, params.userShare, address(this));

        // deduct any fees if required for protocol

        // no swapping required for now
        if (params.swapAmount != 0) {
            params.key.pool.swapToken(address(this), params.zeroForOne, params.swapAmount);
        }

        // custom amount0 or amount1 should be added for next time
        params.key.pool.mintLiquidity(params.key.tickLower, params.key.tickUpper, params.amount0, params.amount1);

        // update state
    }

    function toggleOperator(address _operator) external {
        _operatorApproved[_operator] = !_operatorApproved[_operator];
    }

    /// @notice Returns the status for a given operator that can operate readjust & pull liquidity
    function isOperator(address _operator) external view returns (bool) {
        return _operatorApproved[_operator];
    }
}
