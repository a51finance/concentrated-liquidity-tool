//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../src/CLTZapIn.sol";
import "../src/interfaces/ICLTBase.sol";
import { IAlgebraPool } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";
import "../src/interfaces/external/IWETH9.sol";

contract ZappInTest is Test {
    // forge test --mt "test_basicAdd" -f "https://arbitrum.gateway.tenderly.co/8VBhOlPk9E6ONw0rbuYgi"
    // f616d064-3cb8-4343-97e6-81e7772e04e4

    CLTZapIn zapIn; // 0x74226579ED541adA94582DC4cD6DDd21f6526863;
    ERC20 constant token0 = ERC20(0x4200000000000000000000000000000000000006); // USDC
    ERC20 constant token1 = ERC20(0xd988097fb8612cc24eeC14542bC03424c656005f); // WETH

    IWETH9 constant weth = IWETH9(0x4200000000000000000000000000000000000006);

    address cltBase = 0x69317029384c3305fC04670c68a2b434e2D8C44C;

    IAlgebraPool constant algebraPool = IAlgebraPool(0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6);
    IAlgebraPool constant algebraPool2 = IAlgebraPool(0x25BA258E510FACA5Ab7Ff941A1584bDD2174c94D); //ETH-USDC

    bytes32 strategyID = 0x4fa677272f9c7c30913c6c388ffc13912b19e21592867194c2f69e022d1760c3;
    bytes32 strategyID2 = 0xd7521d176416b0a820d34e41c3a65845a3339c50093e8533b96a62b6a25ec867; //ETH-USDC

    function setUp() public {
        zapIn = new CLTZapIn({
            odosRouterV2: 0x7E15EB462cdc67Cf92Af1f7102465a8F8c784874,
            cltBase: ICLTBase(cltBase),
            weth: weth,
            owner: address(this)
        });
        console.log("ZapIn Address", address(zapIn));
    }

    function approveToken(uint256 amount, ERC20 token, address to) internal {
        token.approve(to, amount);
    }

    function test_basicAdd() external {
        uint256 amount0Desired = 1e18;
        uint256 amount1Desired = 2622 * 1e6;

        // mint tokens
        deal(address(token0), address(this), amount0Desired);
        deal(address(token1), address(this), amount1Desired);

        approveToken(amount0Desired, token0, address(zapIn));
        approveToken(amount1Desired, token1, address(zapIn));

        console.log("Token0 Allowance Before", token0.allowance(address(zapIn), address(cltBase)));
        console.log("Token1 Allowance Before", token1.allowance(address(zapIn), address(cltBase)));

        (uint256 shares,,,) = zapIn.zapIn(
            ICLTBase.DepositParams({
                strategyId: strategyID2,
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

    function test__multicallSwap__zappIn() public {
        uint256 totalAmount1 = 6800 * 1e6;
        uint256 amount1Desired = totalAmount1 / 2;

        address user = 0x3463255E4A3e54c6b74910F4CfBAD03458371f0d;

        deal(address(token1), user, totalAmount1);
        payable(user).transfer(100 ether);

        vm.startPrank(user);
        approveToken(totalAmount1, token1, address(zapIn));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            zapIn.doOKXSwap.selector,
            address(token1),
            amount1Desired,
            address(token0),
            0,
            address(zapIn),
            address(zapIn),
            false,
            block.timestamp + 1 days,
            hex"84a7f3dd0101000156c85a254DD12eE8D9C04049a4ab62769Ce982100c0116beafb2310b60000000000001d988097fb8612cc24eec14542bc03424c656005f04caa7e2000000000142000000000000000000000000000000000000060413658ffa00015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000004019b57dca972db5d8866c630554acdbdfe58b2659c0000000301020300060101010200ff000000000000000000000000000000000000000000468cc91df6f669cae6cdce766995bd7874052fbcd988097fb8612cc24eec14542bc03424c656005f00000000000000000000000000000000000000000000000000000000000000"
        );

        calls[1] = abi.encodeWithSelector(
            zapIn.zapIn.selector,
            ICLTBase.DepositParams({
                strategyId: strategyID2,
                amount0Desired: token0.balanceOf(address(zapIn)),
                amount1Desired: amount1Desired, // amount1 to be fetched by ratio
                amount0Min: 0,
                amount1Min: 0,
                recipient: user
            }),
            token0,
            token1,
            true,
            false
        );

        bytes[] memory results = zapIn.multicall{ value: 1 ether }(calls);

        (uint256 shares,,,) = abi.decode(results[1], (uint256, uint128, uint256, uint256));

        console.log("share -> ", shares);
        assertEq(token0.balanceOf(address(zapIn)), 0);
        assertEq(token1.balanceOf(address(zapIn)), 0);
    }
}
