// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { RebaseModuleMock } from "./mocks/RebaseModule.Mock.sol";
import { ModeTicksCalculation } from "../src/base/ModeTicksCalculation.sol";

contract RebasingModulesTest is Test, ModeTicksCalculation {
    Vm hevm = Vm(HEVM_ADDRESS);

    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public poolAddressPositiveTicks = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // USDC-ETH
    address public poolAddressNegativeTicks = 0x60594a405d53811d3BC4766596EFD80fd545A270; // DAI-ETH
    // address public baseContractAddress = 0xCeA591CC4E4114cd4537B72e5640f0f60E9BCB10;
    // address public rebaseModuleContractAddress = 0xC4a2C558fDBeEF505105438e97A77A0073ecd792;
    address public owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;

    IUniswapV3Factory uniswapV3FactoryContract = IUniswapV3Factory(uniswapV3Factory);
    IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddressPositiveTicks);

    ICLTBase.StrategyKey public strategyKey;

    CLTBase public baseContract;
    RebaseModuleMock public rebaseModuleMockContract;

    function setUp() public {
        baseContract = new CLTBase("ALP TOKEN", "ALPT", owner, WETH9, uniswapV3FactoryContract);
        rebaseModuleMockContract = new RebaseModuleMock(owner,address(baseContract));
    }

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function getStrategyKey() public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick, poolContract.tickSpacing());
        (tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = _floor(tick + 2000, poolContract.tickSpacing());

        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
    }

    function createStrategy() public {
        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModuleMockContract)
        );
        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModuleMockContract)
        );

        ICLTBase.ActionDetails memory actionDetails;

        ICLTBase.StrategyDetail[] memory details = new ICLTBase.StrategyDetail[](2);

        details[0].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        details[0].data = abi.encode(uint256(10), uint256(23));

        details[1].actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        details[1].data = abi.encode(uint256(block.timestamp + 1000));

        actionDetails.mode = 2;
        actionDetails.exitStrategy = new ICLTBase.StrategyDetail[](0);
        actionDetails.rebaseStrategy = details;
        actionDetails.liquidityDistribution = new ICLTBase.StrategyDetail[](0);

        baseContract.createStrategy(strategyKey, actionDetails, true);
    }

    function testRebaseDeploymentCheck() public {
        assertEq(rebaseModuleMockContract.isOperator(address(this)), false);
        hevm.prank(owner);
        rebaseModuleMockContract.toggleOperator(address(this));
        assertEq(rebaseModuleMockContract.isOperator(address(this)), true);
    }

    function testRebasePricePreference() public {
        getStrategyKey();
        createStrategy();
    }

    // check input data test cases
    // Price preference

    function testInputDataPricePreferenceWithValidInputs() public view {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(10), uint256(30));
        rebaseModuleMockContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(203_247), uint256(10_000));
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testInputDataPricePreferenceWithInValidInputs() public {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(0), uint256(30));

        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(0), uint256(0));

        selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // Time preference

    function testCheckInputDataTimePreferenceWithValidInputs() public view {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp + 3600));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testCheckInputDataTimePreferenceWithInvalidInputs() public {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();

        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(0));
        selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(block.timestamp + 31_537_000));
        selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // Rebase Inactivity

    function testInputDataRebaseInActivityWithValidInputs() public view {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(2));
        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();

        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testInputDataRebaseInActivityWithInValidInputs() public {
        ICLTBase.StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(0));

        bytes4 selector = bytes4(keccak256("RebaseInactivityCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // _checkRebasePreferenceStrategies

    function testGetPreferenceTicks() public {
        getStrategyKey();
        (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 20, 30);
        // positive ticks

        assertEq(tl, strategyKey.tickLower - 20);
        assertEq(tu, strategyKey.tickUpper + 30);
        assertEq(strategyKey.tickLower - 20 < strategyKey.tickLower, true);
        assertEq(strategyKey.tickUpper + 30 > strategyKey.tickUpper, true);

        // negative ticks
        poolContract = IUniswapV3Pool(poolAddressNegativeTicks);
        getStrategyKey();
        (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 20, 30);

        assertEq(tl, strategyKey.tickLower - 20);
        assertEq(tu, strategyKey.tickUpper + 30);
        assertEq(strategyKey.tickLower - 20 < strategyKey.tickLower, true);
        assertEq(strategyKey.tickUpper + 30 > strategyKey.tickUpper, true);
    }

    function testCheckRebasePreferenceStrategiesValidInputs() public {
        getStrategyKey();
        bytes memory data = abi.encode(uint256(10), uint256(30));
        (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
        int24 tick = getTwap(strategyKey.pool);
        bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data);
        assertEq(success, (tick < tl || tick > tu));
    }
}
