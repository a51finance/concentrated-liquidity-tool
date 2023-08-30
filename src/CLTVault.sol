// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTVault.sol";

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTVault is ICLTVault, ERC721 {
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    IUniswapV3Pool public pool;
    mapping(uint256 => Position) private positions;

    constructor(address _pool, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function deposit() external { }
    function withdraw() external { }
    function claim() external { }
    function shiftLiquidity() external { }
}
