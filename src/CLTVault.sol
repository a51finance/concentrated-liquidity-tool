// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTVault.sol";

import "./libraries/PoolActions.sol";

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTVault is ICLTVault, ERC721 {
    using PoolActions for IUniswapV3Pool;

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    int24 public immutable tickSpacing;

    IUniswapV3Pool public pool;
    mapping(uint256 => Position) private positions;

    constructor(address _pool, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
        tickSpacing = pool.tickSpacing();
    }

    function deposit() external { }
    function withdraw() external { }

    function claim(address recipient, int24 tickLower, int24 tickUpper) external {
        pool.collectPendingFees(recipient, tickLower, tickUpper);
    }

    function shiftLiquidity(
        uint256 userShare,
        int256 swapAmount,
        bool zeroForOne,
        int24 tickLower,
        int24 tickUpper
    )
        external
    {
        // checks
        pool.checkRange(tickLower, tickUpper, tickSpacing);

        (,, uint256 fees0, uint256 fees1) = pool.burnUserLiquidity(tickLower, tickUpper, userShare, address(this));

        // deduct any fees if required for protocol

        // no swapping required for now
        if (swapAmount != 0) {
            pool.swapToken(address(this), zeroForOne, swapAmount);
        }

        // custom amount0 or amount1 should be added for next time
        pool.mintLiquidity(tickLower, tickUpper, token0.balanceOf(address(this)), token0.balanceOf(address(this)));

        // update state
    }
}
