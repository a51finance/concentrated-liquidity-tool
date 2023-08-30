// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTVault.sol";

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./libraries/PoolActions.sol";

contract CLTVault is ICLTVault, ERC721 {
    using PoolActions for IUniswapV3Pool;

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    IUniswapV3Pool public pool;
    mapping(uint256 => Position) private positions;
    uint256 private _nextId = 1;

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction too old");
        _;
    }

    constructor(address _pool, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function deposit(DepositParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (liquidity, amount0, amount1) =
            pool.mintLiquidity(params.tickLower, params.tickUpper, params.amount0Desired, params.amount1Desired);
        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "Price slippage check");

        _mint(params.recipient, (tokenId = _nextId++));

        positions[tokenId] =
            Position({ tickLower: params.tickLower, tickUpper: params.tickUpper, liquidity: liquidity });

        emit Deposit(tokenId, liquidity, amount0, amount1);
    }

    function withdraw() external { }
    function claim() external { }
    function shiftLiquidity() external { }
}
