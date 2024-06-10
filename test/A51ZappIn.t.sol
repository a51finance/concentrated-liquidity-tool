//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "forge-std/Test.sol";
import "../src/A51ZappIn.sol";
import "../src/interfaces/ICLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";

// forge test --mt "test_basicAdd" -f "https://arbitrum.gateway.tenderly.co/8VBhOlPk9E6ONw0rbuYgi"
// f616d064-3cb8-4343-97e6-81e7772e04e4

contract A51ZappInTest is Test {
    A51ZappIn zap;
    ERC20 constant token0 = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    ERC20 constant token1 = ERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    //
    IUniswapV3Pool constant uniswapPool = IUniswapV3Pool(0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6);
    bytes32 strategyID = 0xa719d2b2d1e3b038d72c688c5d4c9067150f7812805afb17730d32978e930a3b;

    function setUp() public {
        zap = new A51ZappIn({
            _okxProxy: 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09,
            _cltBase: ICLTBase(0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6),
            _tokenApprover: 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58
        });

        token0.approve(address(zap), type(uint256).max);
        token1.approve(address(zap), type(uint256).max);
        token0.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
        token1.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
    }

    // function test_basicAdd() external {
    //     uint256 amount0Desired = 1e18;
    //     uint256 amount1Desired = 1.77e18;

    //     // mint tokens
    //     deal(address(token0), address(this), amount0Desired);
    //     deal(address(token1), address(this), amount1Desired);

    //     (uint256 shares,,,) = zap.zapIn(
    //         ICLTBase.DepositParams({
    //             strategyId: strategyID,
    //             amount0Desired: amount0Desired,
    //             amount1Desired: amount1Desired,
    //             amount0Min: 0,
    //             amount1Min: 0,
    //             recipient: address(this)
    //         }),
    //         token0,
    //         token1
    //     );

    //     assertGt(shares, 0, "shares is zero");
    //     assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
    //     assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    // }

    function test__multicallSwap__zappIn() public {
        uint256 amount0Desired = 1_000_000e6;
        uint256 amount1Desired = 1_000_000e6;

        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        bytes[] memory calls = new bytes[](2);

        calls[0] = abi.encodeWithSelector(
            zap.doZeroExSwap.selector,
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            1_000_000_000,
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
            950_214_223,
            address(zap),
            0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
            1_718_104_276,
            hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000000000000000000000000000000000003b9aca000000000000000000000000000000000000000000000000000000000038a31e4f000000000000000000000000000000000000000000000000000000006666ed2a0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000003b9aca00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000010000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe000000000000000000000000000000000000000000000000000000000000000010000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe00000000000000000000000000000000000000000000000000000000000000001000000000000000000002710a17afcab059f3c6751f5b64347b5a503c32918680000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb90000000000000000000000000000000000000000000000000000000000000000"
        );

        calls[1] = abi.encodeWithSelector(
            zap.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: 1_000_000_000,
                amount1Desired: 1_000_000_000,
                amount0Min: 0,
                amount1Min: 0,
                recipient: 0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb
            }),
            token0,
            token1,
            false,
            true
        );

        bytes[] memory results = zap.multicall(calls);
        // (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));
    }
}
