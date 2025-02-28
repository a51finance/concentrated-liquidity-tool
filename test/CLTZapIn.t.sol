//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "forge-std/Test.sol";
import "../src/CLTZapIn.sol";
import "../src/interfaces/ICLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";
import "../src/interfaces/external/IWETH9.sol";

contract A51ZappInTest is Test {
// A51ZappIn zapIn;
// ERC20 constant token0 = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); //USDC
// ERC20 constant token1 = ERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
// ERC20 constant token2 = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); //DAI

// ERC20 constant token0 = ERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f); //WBTC
// ERC20 constant token1 = ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

// IWETH9 constant weth = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
// address cltBase = 0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6;
// address tokenApprover = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
// CLTZapIn zapIn; // = CLTZappIn(0x74226579ED541adA94582DC4cD6DDd21f6526863);
// IUniswapV3Pool constant uniswapPool = IUniswapV3Pool(0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6);
// IUniswapV3Pool constant uniswapPool2 = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0); //ETH-USDC
// bytes32 strategyID = 0x4fa677272f9c7c30913c6c388ffc13912b19e21592867194c2f69e022d1760c3;
// bytes32 strategyID2 = 0x574712806f505493ea90acd4a2073b4daccde2a392dc97fa363ad477d0ea841d; //ETH-USDC

// function setUp() public {
//     zapIn = new CLTZapIn({
//         okxProxy: 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09,
//         cltBase: ICLTBase(cltBase),
//         tokenApprover: tokenApprover,
//         weth: weth,
//         owner: address(this)
//     });
//     // console.log("ZapIn Address", address(zapIn));
// }

// function approveToken(uint256 amount, ERC20 token, address to) internal {
//     token.approve(to, amount);
// }

// function test_basicAdd() external {
//     uint256 amount0Desired = 1e18;
//     uint256 amount1Desired = 1.77e18;

//     // mint tokens
//     deal(address(token0), address(this), amount0Desired);
//     deal(address(token1), address(this), amount1Desired);

//     console.log("Token0 Allowance Before", token0.allowance(address(zapIn), address(cltBase)));
//     console.log("Token1 Allowance Before", token1.allowance(address(zapIn), address(cltBase)));

//     (uint256 shares,,,) = zapIn.zapIn(
//         ICLTBase.DepositParams({
//             strategyId: strategyID,
//             amount0Desired: amount0Desired,
//             amount1Desired: amount1Desired,
//             amount0Min: 0,
//             amount1Min: 0,
//             recipient: address(this)
//         }),
//         token0,
//         token1,
//         false,
//         false
//     );

//     console.log("Token0 Allowance After", token0.allowance(address(zapIn), address(cltBase)));
//     console.log("Token1 Allowance After", token1.allowance(address(zapIn), address(cltBase)));

//     assertGt(shares, 0, "shares are zero");
//     assertEq(token0.balanceOf(address(zapIn)), 0, "zap has token0 balance");
//     assertEq(token1.balanceOf(address(zapIn)), 0, "zap has token1 balance");
// }

// function test_multicall_wrapEthAndZap() external {
//     uint256 amount0Desired = 1e18; // WETH
//     uint256 amount1Desired = 3500e6; // USDC

//     // mint tokens
//     deal(address(token0), address(this), amount1Desired);
//     token0.approve(address(zapIn), amount1Desired);

//     // make multicall
//     bytes[] memory calls = new bytes[](2);
//     calls[0] = abi.encodeWithSelector(zapIn.wrapEthInput.selector);

//     calls[1] = abi.encodeWithSelector(
//         zapIn.zapIn.selector,
//         ICLTBase.DepositParams({
//             strategyId: strategyID2,
//             amount0Desired: amount0Desired,
//             amount1Desired: amount1Desired,
//             amount0Min: 0,
//             amount1Min: 0,
//             recipient: address(this)
//         }),
//         uniswapPool2.token0(),
//         uniswapPool2.token1(),
//         true,
//         false
//     );

//     bytes[] memory results = zapIn.multicall{ value: 1 ether }(calls);
//     (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));

//     assertGt(shares, 0, "shares is zero");
//     assertEq(weth.balanceOf(address(zapIn)), 0, "zap has token0 balance");
//     assertEq(token0.balanceOf(address(zapIn)), 0, "zap has token1 balance");
// }

// function test__multicallSwap__zappIn() public {
//     uint256 totalAmount0 = 1e8;
//     uint256 amount0Desired = totalAmount0 / 2;

//     // deal(address(token0), address(this), totalAmount0);
//     vm.prank(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89);
//     token0.approve(address(zapIn), totalAmount0);
//     console.log(token0.allowance(address(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89), address(zapIn)));
//     console.log(token0.balanceOf(address(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89)));

//     bytes[] memory calls = new bytes[](2);
//     calls[0] = abi.encodeWithSelector(
//         zapIn.doOKXSwap.selector,
//         address(token0),
//         amount0Desired,
//         address(token1),
//         10_894_206_511_233_801_685,
//         address(zapIn),
//         address(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89),
//         false,
//         block.timestamp + 1 days,
//         hex"0d5f0e3b00000000000000000001901b5615deb798bb3e4dfa0139dfa1b3d433cc23b72f00000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000000000000000001f3b09000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000018000000000000000000000002f5e87c9312fa29aed5c179e456625d79015299c"
//     );

//     calls[1] = abi.encodeWithSelector(
//         zapIn.zapIn.selector,
//         ICLTBase.DepositParams({
//             strategyId: strategyID,
//             amount0Desired: amount0Desired,
//             amount1Desired: 10e18, // amount1 to be fetched by ratio
//             amount0Min: 0,
//             amount1Min: 0,
//             recipient: address(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89)
//         }),
//         token0,
//         token1,
//         false,
//         true
//     );
//     vm.prank(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89);

//     console.logBytes(calls[0]);
//     console.logBytes(calls[1]);

//     bytes[] memory results = zapIn.multicall(calls);

//     (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));
//     assertEq(token0.balanceOf(address(zapIn)), 0);
//     assertEq(token1.balanceOf(address(zapIn)), 0);
// }

// function test__multicall__wrapETH__Swap__zappIn() public {
//     uint256 totalAmount0 = 5e18;
//     uint256 amount0Desired = totalAmount0 / 2;
//     uint256 amount1Desired = 1_925_510;

//     console.log(address(this));

//     bytes[] memory calls = new bytes[](3);

//     calls[0] = abi.encodeWithSelector(zapIn.wrapEthInput.selector);
//     //  hex"e8ab6f2d";

//     //
// hex"3cf8701e00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000001fb14300000000000000000000000074226579ed541ada94582dc4cd6ddd21f652686300000000000000000000000074226579ed541ada94582dc4cd6ddd21f652686300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000066c882ba00000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000d84b80c2f09000000000000000000000000000000000000000000000000000000000001901b00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000000000000000001fb1430000000000000000000000000000000000000000000000000000000066c882ba000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000d600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000053444835ec5800000000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe000000000000000000000000000000000000000000000000000000000000000028000000000000000000019c84bfc22a4da7f31f8a912a79a7e44a822398b4390800000000000000000000d48d845f7d4f4deb9ff5bcf09d140ef13718f6f6c7100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe100000000000000000000000000000000000000000000000000000000000000010000000000000000000027107fcdc35463e3770c2fb992716cd070b63540b9470000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c700000000000000000000000047b5bc2c49ad25dfa6d7363c5e9b28ef804e11850000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c7000000000000000000000000869f51989bbe4a49a03daf49ec57572fccef3b8100000000000000000000000000000000000000000000000000000000000000038000000000000000000012c0843ac8dc6d34aeb07a56812b8b36429ee46bdd07800000000000000000000c800e4831319a50228b9e450861297ab92dee15b44f8000000000000000000007d0869f51989bbe4a49a03daf49ec57572fccef3b81000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
//     calls[1] = abi.encodeWithSelector(
//         zapIn.doOKXSwap.selector,
//         address(weth), // tokenIn
//         amount0Desired,
//         address(token0),
//         10_395_623,
//         address(zapIn),
//         address(zapIn),
//         true,
//         block.timestamp + 1 days,
//         hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000022b1c8c1227a000000000000000000000000000000000000000000000000000000000000009e820f0000000000000000000000000000000000000000000000000000000066c8880e000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000020f5b1eaad8d800000000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000020000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe0000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe100000000000000000000000000000000000000000000000000000000000000020000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe0000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000000000000000000000000000000000000000000002800000000000000000002260d845f7d4f4deb9ff5bcf09d140ef13718f6f6c718000000000000000000004b04bfc22a4da7f31f8a912a79a7e44a822398b439000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c700000000000000000000000000000000000000000000000000000000000000020000000000000000000014507fcdc35463e3770c2fb992716cd070b63540b9470000000000000000000012c06f38e884725a116c9c7fbf208e79fe8828a2595f00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000000100000000000000000000000047b5bc2c49ad25dfa6d7363c5e9b28ef804e11850000000000000000000000000000000000000000000000000000000000000001000000000000000000000000869f51989bbe4a49a03daf49ec57572fccef3b810000000000000000000000000000000000000000000000000000000000000001800000000000000000002710869f51989bbe4a49a03daf49ec57572fccef3b8100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
//     );

//     //
// hex"5a63cf774fa677272f9c7c30913c6c388ffc13912b19e21592867194c2f69e022d1760c3000000000000000000000000000000000000000000000000000000000005e04100000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0e9e6b79a3e1ab87feb209567ef3e0373210a890000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
//     calls[2] = abi.encodeWithSelector(
//         zapIn.zapIn.selector,
//         ICLTBase.DepositParams({
//             strategyId: strategyID,
//             amount0Desired: amount1Desired,
//             amount1Desired: amount0Desired, // amount1 to be fetched by ratio
//             amount0Min: 10_395_623,
//             amount1Min: 0,
//             recipient: address(this)
//         }),
//         token0,
//         weth,
//         true,
//         true
//     );
//     console.logBytes(calls[0]);
//     console.logBytes(calls[1]);
//     console.logBytes(calls[2]);
//     vm.prank(0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89);
//     bytes[] memory results = zapIn.multicall{ value: 5 ether }(calls);

//     (uint256 shares,,,) = abi.decode(results[2], (uint256, uint128, uint256, uint256));
//     assertGt(shares, 0, "shares is zero");
//     assertEq(token0.balanceOf(address(zapIn)), 0);
//     assertEq(token1.balanceOf(address(zapIn)), 0);
// }

// function test__multicall__wrapETH__Swap__zappIncrease() public {
//     uint256 totalAmount0 = 5e18;
//     uint256 amount0Desired = totalAmount0 / 2;
//     uint256 amount1Desired = 1_925_510;

//     console.log(address(this));
//     vm.prank(0x7c51FDF3185f4D5C7372Dd15091d03B967399fC6);
//     ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).approve(address(zapIn), 100_000_000_000_000_000_000);
//     vm.prank(0x7c51FDF3185f4D5C7372Dd15091d03B967399fC6);
//     ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(zapIn), 100_000_000_000_000_000_000);

//     bytes[] memory calls = new bytes[](2);

//     // calls[0] = abi.encodeWithSelector(zapIn.wrapEthInput.selector);
//     //  hex"e8ab6f2d";

//     //
// hex"3cf8701e00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000001fb14300000000000000000000000074226579ed541ada94582dc4cd6ddd21f652686300000000000000000000000074226579ed541ada94582dc4cd6ddd21f652686300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000066c882ba00000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000d84b80c2f09000000000000000000000000000000000000000000000000000000000001901b00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000000000000000001fb1430000000000000000000000000000000000000000000000000000000066c882ba000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000d600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000053444835ec5800000000000000000000000000000000000000000000000000001bc16d674ec80000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe000000000000000000000000000000000000000000000000000000000000000028000000000000000000019c84bfc22a4da7f31f8a912a79a7e44a822398b4390800000000000000000000d48d845f7d4f4deb9ff5bcf09d140ef13718f6f6c7100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe100000000000000000000000000000000000000000000000000000000000000010000000000000000000027107fcdc35463e3770c2fb992716cd070b63540b9470000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c700000000000000000000000047b5bc2c49ad25dfa6d7363c5e9b28ef804e11850000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe1000000000000000000000000443ef018e182d409bcf7f794d409bcea4c73c2c7000000000000000000000000869f51989bbe4a49a03daf49ec57572fccef3b8100000000000000000000000000000000000000000000000000000000000000038000000000000000000012c0843ac8dc6d34aeb07a56812b8b36429ee46bdd07800000000000000000000c800e4831319a50228b9e450861297ab92dee15b44f8000000000000000000007d0869f51989bbe4a49a03daf49ec57572fccef3b81000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
//     calls[0] = abi.encodeWithSelector(
//         zapIn.doOKXSwap.selector,
//         0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // tokenIn
//         903_501,
//         0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
//         313_297_849_539_897,
//         address(zapIn),
//         address(0x7c51FDF3185f4D5C7372Dd15091d03B967399fC6),
//         false,
//         block.timestamp + 1 days,
//         hex"0d5f0e3b00000000000000000001901b7c51fdf3185f4d5c7372dd15091d03b967399fc600000000000000000000000000000000000000000000000000000000000dc94d00000000000000000000000000000000000000000000000000011cf15707dd39000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000018000000000000000000000006f38e884725a116c9c7fbf208e79fe8828a2595f"
//     );

//     //
// hex"5a63cf774fa677272f9c7c30913c6c388ffc13912b19e21592867194c2f69e022d1760c3000000000000000000000000000000000000000000000000000000000005e04100000000000000000000000000000000000000000000000006f05b59d3b2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0e9e6b79a3e1ab87feb209567ef3e0373210a890000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
//     calls[1] = abi.encodeWithSelector(
//         zapIn.zapIncrease.selector,
//         ICLTBase.UpdatePositionParams({
//             tokenId: 127,
//             amount0Desired: 127_928_426_214_213,
//             amount1Desired: 903_501, // amount1 to be fetched by ratio
//             amount0Min: 0,
//             amount1Min: 0
//         }),
//         0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
//         0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
//         false,
//         true
//     );
//     console.logBytes(calls[0]);
//     console.logBytes(calls[1]);
//     vm.prank(0x7c51FDF3185f4D5C7372Dd15091d03B967399fC6);
//     bytes[] memory results = zapIn.multicall(calls);

//     (uint256 shares,,) = abi.decode(results[2], (uint128, uint256, uint256));
//     assertGt(shares, 0, "shares is zero");
//     assertEq(token0.balanceOf(address(zapIn)), 0);
//     assertEq(token1.balanceOf(address(zapIn)), 0);
// }
// /**
//  * function test__multicallSwap__zappIn__thirdToken() public {
//  *     uint256 thirdTokenAmount = 90e18;
//  *     uint256 amount0Desired = 43e6;
//  *     uint256 amount1Desired = 43e6;
//  *
//  *     deal(address(token2), address(this), thirdTokenAmount);
//  *     token2.approve(address(zapIn), type(uint256).max);
//  *     token2.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
//  *
//  *     bytes[] memory calls = new bytes[](3);
//  *
//  *     // swap token0 from token2
//  *     calls[0] = abi.encodeWithSelector(
//  *         zapIn.doOKXSwap.selector,
//  *         address(token2),
//  *         45e18,
//  *         address(token0),
//  *         42_745_690,
//  *         address(zapIn),
//  *         0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
//  *         block.timestamp + 1 days,
//  *         hex"0d5f0e3b00000000000000000001901b67822177489fd6e28cdcb52e90f53d10740e01bd00000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028c3f59000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000018000000000000000000000007cf803e8d82a50504180f417b8bc7a493c0a0503"
//  *     );
//  *
//  *     // swap token1 from token2
//  *     calls[1] = abi.encodeWithSelector(
//  *         zapIn.doOKXSwap.selector,
//  *         address(token2),
//  *         45e18,
//  *         address(token1),
//  *         42_104_745,
//  *         address(zapIn),
//  *         0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
//  *         block.timestamp + 1 days,
//  *         hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da1000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028277a80000000000000000000000000000000000000000000000000000000066742c5f0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000270801d946c940000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b06a44aa660537fb3f6482d65ff5b0c7d58dc1eb000000000000000000000000000000000000000000000000000000000000000100000000000000000000000015b9d20bcaa4f65d9004d2bebac4058445fd5285000000000000000000000000000000000000000000000000000000000000000100000000000000000000271015b9d20bcaa4f65d9004d2bebac4058445fd528500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
//  *     );
//  *     // we need to encounter the fee deduction from okx and uniswap while depositing
//  *     // Deposit Liquidity
//  *     calls[2] = abi.encodeWithSelector(
//  *         zapIn.zapIn.selector,
//  *         ICLTBase.DepositParams({
//  *             strategyId: strategyID,
//  *             amount0Desired: amount0Desired,
//  *             amount1Desired: amount1Desired,
//  *             amount0Min: 0,
//  *             amount1Min: 0,
//  *             recipient: 0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb
//  *         }),
//  *         token0,
//  *         token1,
//  *         true,
//  *         true
//  *     );
//  *     bytes[] memory results = zapIn.multicall(calls);
//  * }
//  */
}
