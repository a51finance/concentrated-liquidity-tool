//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "forge-std/Test.sol";
import "../src/CLTZappIn.sol";
import "../src/interfaces/ICLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";
import "../src/interfaces/external/IWETH9.sol";

contract A51ZappInTest is Test {
    // A51ZappIn zapIn;
    ERC20 constant token0 = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); //USDC
    ERC20 constant token1 = ERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    ERC20 constant token2 = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); //DAI
    IWETH9 constant weth = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address cltBase = 0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6;
    address tokenApprover = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
    CLTZappIn zapIn; // = CLTZappIn(0x67822177489fD6e28cDCb52E90f53D10740E01bd);
    IUniswapV3Pool constant uniswapPool = IUniswapV3Pool(0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6);
    IUniswapV3Pool constant uniswapPool2 = IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0); //ETH-USDC
    bytes32 strategyID = 0xa719d2b2d1e3b038d72c688c5d4c9067150f7812805afb17730d32978e930a3b;
    bytes32 strategyID2 = 0x574712806f505493ea90acd4a2073b4daccde2a392dc97fa363ad477d0ea841d; //ETH-USDC

    function setUp() public {
        zapIn = new CLTZappIn({
            okxProxy: 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09,
            cltBase: ICLTBase(cltBase),
            tokenApprover: tokenApprover,
            weth: weth
        });
        console.log("ZapIn Address", address(zapIn));
    }

    function approveToken(uint256 amount, ERC20 token, address to) internal {
        token.approve(to, amount);
    }

    function test_basicAdd() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        console.log("Token0 Allowance Before", token0.allowance(address(zapIn), address(cltBase)));
        console.log("Token1 Allowance Before", token1.allowance(address(zapIn), address(cltBase)));

        (uint256 shares,,,) = zapIn.zapIn(
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            }),
            token0,
            token1,
            false,
            false
        );

        console.log("Token0 Allowance After", token0.allowance(address(zapIn), address(cltBase)));
        console.log("Token1 Allowance After", token1.allowance(address(zapIn), address(cltBase)));

        assertGt(shares, 0, "shares are zero");
        assertEq(token0.balanceOf(address(zapIn)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zapIn)), 0, "zap has token1 balance");
    }

    function test_multicall_wrapEthAndZap() external {
        uint256 amount0Desired = 1e18; // WETH
        uint256 amount1Desired = 3500e6; // USDC

        // mint tokens
        deal(address(token0), address(this), amount1Desired);
        token0.approve(address(zapIn), amount1Desired);

        // make multicall
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(zapIn.wrapEthInput.selector);

        calls[1] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            }),
            uniswapPool2.token0(),
            uniswapPool2.token1(),
            true,
            false
        );

        bytes[] memory results = zapIn.multicall{ value: 1 ether }(calls);
        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));

        assertGt(shares, 0, "shares is zero");
        assertEq(weth.balanceOf(address(zapIn)), 0, "zap has token0 balance");
        assertEq(token0.balanceOf(address(zapIn)), 0, "zap has token1 balance");
    }

    function test__multicallSwap__zappIn() public {
        uint256 totalAmount0 = 1000e6;
        uint256 amount0Desired = totalAmount0 / 2;

        deal(address(token0), address(this), totalAmount0);

        token0.approve(address(zapIn), totalAmount0);

        console.log(token0.allowance(address(this), address(zapIn)));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            zapIn.doZeroExSwap.selector,
            address(token0),
            500e6,
            address(token1),
            474_961_570,
            address(zapIn),
            address(this),
            false,
            block.timestamp + 1 days,
            hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000000000000000000000000000000000001dcd6500000000000000000000000000000000000000000000000000000000001c4f56a100000000000000000000000000000000000000000000000000000000669f9fe10000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000001dcd6500000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000010000000000000000000000002fa31d2ac017869998f9574bac76094a8110cf7c00000000000000000000000000000000000000000000000000000000000000010000000000000000000000002fa31d2ac017869998f9574bac76094a8110cf7c0000000000000000000000000000000000000000000000000000000000000001000000000000000000002710cc065eb6460272481216757293ffc54a061ba60e0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000"
        );

        calls[1] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: amount0Desired,
                amount1Desired: amount0Desired, // amount1 to be fetched by ratio
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            }),
            token0,
            token1,
            false,
            true
        );
        bytes[] memory results = zapIn.multicall(calls);
        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));
        assertEq(token0.balanceOf(address(zapIn)), 0);
        assertEq(token1.balanceOf(address(zapIn)), 0);
    }

    function test__multicall__wrapETH__Swap__zappIn() public {
        uint256 totalAmount0 = 5e18;
        uint256 amount0Desired = totalAmount0 / 2;
        uint256 amount1Desired = 2.5 * 3500e6;

        bytes[] memory calls = new bytes[](3);

        calls[0] = abi.encodeWithSelector(zapIn.wrapEthInput.selector);

        calls[1] = abi.encodeWithSelector(
            zapIn.doZeroExSwap.selector,
            address(weth), // tokenIn
            amount0Desired,
            address(token0),
            8_238_895_296,
            address(zapIn),
            address(zapIn),
            true,
            block.timestamp + 1 days,
            hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b00000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000022b1c8c1227a000000000000000000000000000000000000000000000000000000000001eb1390bf0000000000000000000000000000000000000000000000000000000066a0ea3c000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000c80000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000018493fba64ef00000000000000000000000000000000000000000000000000000a688906bd8b00000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000020000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe0000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe100000000000000000000000000000000000000000000000000000000000000020000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe0000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000000000000000000000000000000000000000000002000000000000000000002008b1026b8e7276e7ac75410f1fcbbe21796e8f75260000000000000000000007087fcdc35463e3770c2fb992716cd070b63540b94700000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0d62be88fa3e42b607b8252d828df6dfcd3dbe10000000000000000000000004e3bcce28caf98a143fd8bd9e4875ccab3e7bbe00000000000000000000000000000000000000000000000000000000000000002000000000000000000001388389938cf14be379217570d8e4619e51fbdafaa210000000000000000000013887cccba38e2d959fe135e79aebb57ccb27b12835800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb90000000000000000000000000000000000000000000000000000000000000001000000000000000000000000bd4991108f931da96f5b4d7cd39d5c8e558a0d2d0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000bd4991108f931da96f5b4d7cd39d5c8e558a0d2d0000000000000000000000000000000000000000000000000000000000000001800000000000000000002710df63268af25a2a69c07d09a88336cd9424269a1f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000000"
        );

        calls[2] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired, // amount1 to be fetched by ratio
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            }),
            weth,
            token0,
            true,
            true
        );
        bytes[] memory results = zapIn.multicall{ value: 5 ether }(calls);

        (uint256 shares,,,) = abi.decode(results[2], (uint256, uint128, uint256, uint256));
        assertGt(shares, 0, "shares is zero");
        assertEq(token0.balanceOf(address(zapIn)), 0);
        assertEq(token1.balanceOf(address(zapIn)), 0);
    }
    // Avoid Swapping from a third token
    /**
     * function test__multicallSwap__zappIn__thirdToken() public {
     *     uint256 thirdTokenAmount = 90e18;
     *     uint256 amount0Desired = 43e6;
     *     uint256 amount1Desired = 43e6;
     *
     *     deal(address(token2), address(this), thirdTokenAmount);
     *     token2.approve(address(zapIn), type(uint256).max);
     *     token2.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
     *
     *     bytes[] memory calls = new bytes[](3);
     *
     *     // swap token0 from token2
     *     calls[0] = abi.encodeWithSelector(
     *         zapIn.doZeroExSwap.selector,
     *         address(token2),
     *         45e18,
     *         address(token0),
     *         42_745_690,
     *         address(zapIn),
     *         0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
     *         block.timestamp + 1 days,
     *         hex"0d5f0e3b00000000000000000001901b67822177489fd6e28cdcb52e90f53d10740e01bd00000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028c3f59000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000018000000000000000000000007cf803e8d82a50504180f417b8bc7a493c0a0503"
     *     );
     *
     *     // swap token1 from token2
     *     calls[1] = abi.encodeWithSelector(
     *         zapIn.doZeroExSwap.selector,
     *         address(token2),
     *         45e18,
     *         address(token1),
     *         42_104_745,
     *         address(zapIn),
     *         0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
     *         block.timestamp + 1 days,
     *         hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da1000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028277a80000000000000000000000000000000000000000000000000000000066742c5f0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000270801d946c940000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b06a44aa660537fb3f6482d65ff5b0c7d58dc1eb000000000000000000000000000000000000000000000000000000000000000100000000000000000000000015b9d20bcaa4f65d9004d2bebac4058445fd5285000000000000000000000000000000000000000000000000000000000000000100000000000000000000271015b9d20bcaa4f65d9004d2bebac4058445fd528500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
     *     );
     *     // we need to encounter the fee deduction from okx and uniswap while depositing
     *     // Deposit Liquidity
     *     calls[2] = abi.encodeWithSelector(
     *         zapIn.zapIn.selector,
     *         ICLTBase.DepositParams({
     *             strategyId: strategyID,
     *             amount0Desired: amount0Desired,
     *             amount1Desired: amount1Desired,
     *             amount0Min: 0,
     *             amount1Min: 0,
     *             recipient: 0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb
     *         }),
     *         token0,
     *         token1,
     *         true,
     *         true
     *     );
     *     bytes[] memory results = zapIn.multicall(calls);
     * }
     */
}
