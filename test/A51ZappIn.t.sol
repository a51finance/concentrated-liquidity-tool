//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "forge-std/Test.sol";
import "../src/A51ZappIn.sol";
import "../src/interfaces/ICLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";

contract A51ZappInTest is Test {
    A51ZappIn zap;
    ERC20 constant token0 = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    ERC20 constant token1 = ERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    ERC20 constant token2 = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); //dai

    A51ZappIn zapIn = A51ZappIn(0x6C681A2465C888D67Bec7848Bf53c5D73e709465);
    IUniswapV3Pool constant uniswapPool = IUniswapV3Pool(0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6);
    bytes32 strategyID = 0xa719d2b2d1e3b038d72c688c5d4c9067150f7812805afb17730d32978e930a3b;

    function setUp() public {
        // zap = A51ZappIn({
        //     _okxProxy: 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09,
        //     _cltBase: ICLTBase(0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6),
        //     _tokenApprover: 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58
        // });

        token0.approve(address(zapIn), type(uint256).max);
        token1.approve(address(zapIn), type(uint256).max);
        token0.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
        token1.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);
    }

    function test_basicAdd() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 1.77e18;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        (uint256 shares,,,) = zap.zapIn(
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

        assertGt(shares, 0, "shares is zero");
        assertEq(token0.balanceOf(address(zap)), 0, "zap has token0 balance");
        assertEq(token1.balanceOf(address(zap)), 0, "zap has token1 balance");
    }

    function test__multicallSwap__zappIn() public {
        uint256 amount0Desired = 500e6;
        uint256 amount1Desired = 500e6;

        deal(address(token0), address(this), 1000e6);

        bytes[] memory calls = new bytes[](2);

        calls[0] = abi.encodeWithSelector(
            zapIn.doZeroExSwap.selector,
            address(token0),
            500e6,
            address(token1),
            475_127_635,
            0x6C681A2465C888D67Bec7848Bf53c5D73e709465,
            0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
            block.timestamp + 1 days,
            hex"b80c2f09000000000000000000000000000000000000000000000000000000000001901b000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9000000000000000000000000000000000000000000000000000000001dcd6500000000000000000000000000000000000000000000000000000000001c51df5300000000000000000000000000000000000000000000000000000000666996d30000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000001dcd6500000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000010000000000000000000000002fa31d2ac017869998f9574bac76094a8110cf7c00000000000000000000000000000000000000000000000000000000000000010000000000000000000000002fa31d2ac017869998f9574bac76094a8110cf7c0000000000000000000000000000000000000000000000000000000000000001000000000000000000002710cc065eb6460272481216757293ffc54a061ba60e0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000"
        );

        calls[1] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: 0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb
            }),
            token0,
            token1,
            false,
            true
        );
        bytes[] memory results = zapIn.multicall(calls);
        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));
        assertEq(token0.balanceOf(0x6C681A2465C888D67Bec7848Bf53c5D73e709465), 0);
        assertEq(token1.balanceOf(0x6C681A2465C888D67Bec7848Bf53c5D73e709465), 0);
    }

    function test__multicallSwap__zappIn__thirdToken() public {
        uint256 thirdTokenAmount = 90e18;
        uint256 amount0Desired = 43e6;
        uint256 amount1Desired = 43e6;

        deal(address(token2), address(this), thirdTokenAmount);
        token2.approve(address(zapIn), type(uint256).max);
        token2.approve(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09), type(uint256).max);

        bytes[] memory calls = new bytes[](3);

        // swap token0 from token2
        calls[0] = abi.encodeWithSelector(
            zapIn.doZeroExSwap.selector,
            address(token2),
            45e18,
            address(token0),
            42_732_668,
            address(zapIn),
            0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
            block.timestamp + 1 days,
            hex"0d5f0e3b00000000000000000001901b6c681a2465c888d67bec7848bf53c5d73e70946500000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028c0c7c000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000018000000000000000000000007cf803e8d82a50504180f417b8bc7a493c0a0503"
        );

        // swap token1 from token2
        calls[1] = abi.encodeWithSelector(
            zapIn.doZeroExSwap.selector,
            address(token2),
            45e18,
            address(token1),
            42_732_668,
            address(zapIn),
            0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb,
            block.timestamp + 1 days,
            hex"0d5f0e3b00000000000000000001901b6c681a2465c888d67bec7848bf53c5d73e70946500000000000000000000000000000000000000000000000270801d946c94000000000000000000000000000000000000000000000000000000000000028c349b000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000007f580f8a02b759c350e6b8340e7c2d4b8162b6a9"
        );
        // we need to encounter the fee deduction from okx and uniswap while depositing
        // Deposit Liquidity
        calls[2] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: 0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb
            }),
            token0,
            token1,
            true,
            true
        );
        bytes[] memory results = zapIn.multicall(calls);
    }
}