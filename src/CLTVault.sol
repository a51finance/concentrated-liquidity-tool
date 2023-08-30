// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "./interfaces/ICLTVault.sol";

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTVault is ICLTVault {
    address public immutable token0;
    address public immutable token1;
    IUniswapV3Pool public immutable pool;

    constructor(address _token0, address _token1, IUniswapV3Pool _pool) {
        token0 = _token0;
        token1 = _token1;
        pool = _pool;
    }

    function deposit() external { }
    function withdraw() external { }
    function claim() external { }
    function shiftLiquidity() external { }
}
