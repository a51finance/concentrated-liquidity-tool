// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../../src/CLTBase.sol";

import { Fixtures } from "./../utils/Fixtures.sol";
import { RebaseModuleMock } from "./../mocks/RebaseModule.mock.sol";
import { CLTModules } from "../../src/CLTModules.sol";
import { ModeTicksCalculation } from "../../src/base/ModeTicksCalculation.sol";

import { ICLTBase } from "../../src/interfaces/ICLTBase.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/console.sol";

contract GoerliFork is Test {
    // addresses
    Vm _hevm = Vm(HEVM_ADDRESS);

    // goerli addresses
    address CLTModulesAddress = 0xa5f6b4a0A57d1e5336A3afFdC9333307B28Dc434;
    address GovernanceFeeHandlerAddress = 0x4cbf46BEC5AAe773d45211943f8dc2d9793CBecd;
    address CLTBaseAddress = 0x4554022f26Cb3056b90ED808584Dba3B2AD51c13;
    address CLTHelperAddress = 0xb2a85fb2257A5c11d6Cfdba887523C80A04e6D68;
    address ModesAddress = 0x4d1cFD89B348CF1481c3e9eb9D6AC0ecB7134f25;
    address RebaseModuleAddress = 0x4fD6D8753c78753d25a60236978b28a1fc826bcf;

    address testingFor = 0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89;

    IUniswapV3Pool poolContract;
    INonfungiblePositionManager.MintParams mintParams;
    CLTBase base;

    function setUp() public {
        base = CLTBase(payable(CLTBaseAddress));
    }

    // forge test --fork-url goerli --fork-block-number 10225131 -vvv --match-test "testPOCLS"
    function testPOCLS() public {
        assertEq(base.cltModules(), CLTModulesAddress);

        (bytes32 strategyId, uint256 liquidityShare,,,,) = base.positions(1);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        console.log("Position Share", liquidityShare);
        console.log("Uniswap Liquidity", account.uniswapLiquidity);

        _hevm.prank(testingFor);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: 3_547_744_935_820_899_648_092,
                recipient: testingFor,
                refundAsETH: true
            })
        );
    }

    // forge test --fork-url goerli --fork-block-number 10225094 -vvvv --match-test "testPOCLSDeposit" --evm-version
    // shanghai
    function testPOCLSDeposit() public {
        assertEq(base.cltModules(), CLTModulesAddress);

        // (bytes32 strategyId, uint256 liquidityShare,,,,) = base.positions(1);
        // (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        _hevm.prank(testingFor);
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: 0x36e3bcb79206102da6d4cf9bd753207d319fbd6a70db211a62c698d588bea6e7,
                amount0Desired: 2_070_698_484_745_169_375_981,
                amount1Desired: 2_070_698_484_745_169_375_981,
                amount0Min: 2_037_636_124_088_211_003_076,
                amount1Min: 297_626_605_449_780_041_384,
                recipient: testingFor
            })
        );
    }
}
