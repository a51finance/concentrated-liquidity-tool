// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { RebaseModuleMock } from "./mocks/RebaseModule.mock.sol";
import { ModeTicksCalculation } from "../src/base/ModeTicksCalculation.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { UniswapDeployer } from "./lib/UniswapDeployer.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract RebasingModulesTest is Test, ModeTicksCalculation, UniswapDeployer {
    Vm _hevm = Vm(HEVM_ADDRESS);

    ISwapRouter.ExactInputSingleParams swapParams;
    NonfungiblePositionManager positionManager;
    IUniswapV3Factory uniswapV3FactoryContract;
    RebaseModuleMock rebaseModuleMockContract;
    IUniswapV3Pool poolContract;
    INonfungiblePositionManager.MintParams mintParams;
    CLTBase baseContract;
    SwapRouter router;
    ERC20Mock token0;
    ERC20Mock token1;
    CLTBase base;
    WETH weth;

    ICLTBase.StrategyKey strategyKey;
    address owner = address(this);
    address alice = _hevm.addr(1);
    address bob = _hevm.addr(2);
    address user1 = _hevm.addr(3);
    address user2 = _hevm.addr(4);

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        if (address(token0) >= address(token1)) {
            (token0, token1) = (token1, token0);
        }

        weth = new WETH();

        token0.mint(owner, 10_000_000_000e18);
        token1.mint(owner, 10_000_000_000e18);

        // intialize uniswap contracts
        weth = new WETH();
        uniswapV3FactoryContract = IUniswapV3Factory(deployUniswapV3Factory());
        poolContract = IUniswapV3Pool(uniswapV3FactoryContract.createPool(address(token0), address(token1), 500));
        poolContract.initialize(TickMath.getSqrtRatioAtTick(0));
        router = new SwapRouter(address(uniswapV3FactoryContract), address(weth));
        positionManager =
        new NonfungiblePositionManager(address(uniswapV3FactoryContract),address(weth),address(uniswapV3FactoryContract));

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-887_272 / poolContract.tickSpacing()) * poolContract.tickSpacing();
        mintParams.tickUpper = (887_272 / poolContract.tickSpacing()) * poolContract.tickSpacing();
        mintParams.fee = 500;
        mintParams.recipient = owner;
        mintParams.amount0Desired = 100_000e18;
        mintParams.amount1Desired = 100_000;
        mintParams.amount0Min = 0;
        mintParams.amount1Min = 0;
        mintParams.deadline = 2_000_000_000;

        token0.approve(address(positionManager), type(uint256).max);
        token1.approve(address(positionManager), type(uint256).max);

        positionManager.mint(mintParams);

        // initialize base contract
        base = new CLTBase("ALP Base", "ALP", owner, address(0), 1000000000000000, uniswapV3FactoryContract);

        // approve tokens
        token0.approve(address(base), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(base), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        // initialize module contract
        rebaseModuleMockContract = new RebaseModuleMock(owner,address(baseContract));
    }

    function generateSwaps(ISwapRouter.ExactInputSingleParams memory params) public {
        router.exactInputSingle(params);
    }

    function getStrategyKey(int24 difference) public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick, poolContract.tickSpacing());
        (tick - difference, poolContract.tickSpacing());
        int24 tickUpper = _floor(tick + difference, poolContract.tickSpacing());

        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
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

    function createStrategy(ICLTBase.PositionActions memory positionActions) public {
        _hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModuleMockContract), true
        );
        _hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModuleMockContract), true
        );

        baseContract.createStrategy(strategyKey, positionActions, true);
    }

    function testRebaseDeploymentCheck() public {
        assertEq(rebaseModuleMockContract.isOperator(alice), false);
        rebaseModuleMockContract.toggleOperator(owner);
        assertEq(rebaseModuleMockContract.isOperator(address(this)), true);
    }

    // checkStrategiesArray Testing
    // Test Case 1: Non-empty Array without Zero ID and without Duplicates

    function testValidArray() public {
        bytes32[] memory data = new bytes32[](3);
        data[0] = keccak256(abi.encodePacked("strategy1"));
        data[1] = keccak256(abi.encodePacked("strategy2"));
        data[2] = keccak256(abi.encodePacked("strategy3"));
        assertTrue(rebaseModuleMockContract.checkStrategiesArray(data));
    }

    // Test Case 2: Empty Array
    function testEmptyArrayReverts() public {
        bytes32[] memory data = new bytes32[](0);
        bytes4 selector = bytes4(keccak256("StrategyIdsCannotBeEmpty()"));
        vm.expectRevert(selector);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 3: Array with Zero ID
    function testArrayWithZeroIdReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = keccak256(abi.encodePacked("strategy1"));
        data[1] = bytes32(0);

        bytes4 selector = bytes4(keccak256("StrategyIdCannotBeZero()"));
        vm.expectRevert(selector);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 4: Array with Duplicates
    function testArrayWithDuplicatesReverts() public {
        bytes32 duplicateId = keccak256("strategy1");
        bytes32[] memory data = new bytes32[](2);
        data[0] = duplicateId;
        data[1] = duplicateId;
        bytes memory encodedError = abi.encodeWithSignature("DuplicateStrategyId(bytes32)", duplicateId);
        vm.expectRevert(encodedError);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 5: Large Array without Issues
    function testLargeArray() public {
        uint256 largeSize = 1000;
        bytes32[] memory data = new bytes32[](largeSize);
        for (uint256 i = 0; i < largeSize; i++) {
            data[i] = keccak256(abi.encodePacked(i));
        }
        assertTrue(rebaseModuleMockContract.checkStrategiesArray(data));
    }

    // Test Case 6: Array with Last Element Zero
    function testArrayWithLastElementZeroReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = keccak256("strategy1");
        data[1] = bytes32(0);
        bytes4 selector = bytes4(keccak256("StrategyIdCannotBeZero()"));
        vm.expectRevert(selector);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 7: Array with First Element Zero
    function testArrayWithFirstElementZeroReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(0);
        data[1] = keccak256("strategy2");
        bytes4 selector = bytes4(keccak256("StrategyIdCannotBeZero()"));
        vm.expectRevert(selector);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 8: Array with All Elements Zero
    function testArrayWithAllElementsZeroReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(0);
        data[1] = bytes32(0);
        bytes4 selector = bytes4(keccak256("StrategyIdCannotBeZero()"));
        vm.expectRevert(selector);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    // Test Case 9: Array with All Elements Identical
    function testArrayWithAllElementsIdenticalReverts() public {
        bytes32 identicalId = keccak256(abi.encodePacked("strategy"));
        bytes32[] memory data = new bytes32[](3);
        data[0] = identicalId;
        data[1] = identicalId;
        data[2] = identicalId;
        bytes memory encodedError = abi.encodeWithSignature("DuplicateStrategyId(bytes32)", identicalId);
        vm.expectRevert(encodedError);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    /*
     * check input data test cases
     */

    // Price Preference
    function testPricePreferenceWithValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(10), uint256(30));
        rebaseModuleMockContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(203_247), uint256(10_000));
        assertTrue(rebaseModuleMockContract.checkInputData(strategyDetail));
    }

    function testPricePreferenceWithLowerPriceZero() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(0), uint256(30));
        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testPricePreferenceWithUpperPriceZero() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(30), uint256(0));
        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testPricePreferenceWithBothPriceZero() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(0), uint256(0));
        bytes4 selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testPricePreferenceWithZeroData() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
        strategyDetail.data = "";
        bytes4 selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // Time preference

    function testTimePreferenceWithValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp + 3600));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        assertTrue(rebaseModuleMockContract.checkInputData(strategyDetail));
    }

    function testTimePreferenceWithCurrentTime() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testTimePreferenceWithPastTime() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp - 36_000));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testTimePreferenceWithFarFutureTime() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp + 31_536_001));
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function testTimePreferenceWithZeroTime() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = "";
        strategyDetail.actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        bytes4 selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // Rebase Inactivity

    function testInputDataRebaseInActivityWithValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(2));
        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        assertTrue(rebaseModuleMockContract.checkInputData(strategyDetail));
    }

    function testInputDataRebaseInActivityWithInValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(0));

        bytes4 selector = bytes4(keccak256("RebaseInactivityCannotBeZero()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    // combined cases

    function testInputDataWithMultipleValidPreferences() public {
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](2);
        strategyDetailArray[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        strategyDetailArray[0].data = abi.encode(uint256(2));
        strategyDetailArray[1].data = abi.encode(uint256(10), uint256(30));

        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            assertTrue(rebaseModuleMockContract.checkInputData(strategyDetailArray[i]));
        }

        strategyDetailArray[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.TIME_PREFERENCE();

        strategyDetailArray[0].data = abi.encode(uint256(2));
        strategyDetailArray[1].data = abi.encode(uint256(block.timestamp + 100));

        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            assertTrue(rebaseModuleMockContract.checkInputData(strategyDetailArray[i]));
        }

        strategyDetailArray = new ICLTBase.StrategyPayload[](3);

        strategyDetailArray[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        strategyDetailArray[2].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        strategyDetailArray[0].data = abi.encode(uint256(2));
        strategyDetailArray[1].data = abi.encode(uint256(block.timestamp + 100));
        strategyDetailArray[2].data = abi.encode(uint256(120), uint256(45));

        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            assertTrue(rebaseModuleMockContract.checkInputData(strategyDetailArray[i]));
        }
    }

    function testInputDataWithMultipleInValidPreferencesOne() public {
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](2);
        strategyDetailArray[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        strategyDetailArray[0].data = abi.encode(uint256(0));
        strategyDetailArray[1].data = abi.encode(uint256(0), uint256(30));

        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            _hevm.expectRevert();
            rebaseModuleMockContract.checkInputData(strategyDetailArray[i]);
        }
    }

    function testInputDataWithMultipleInValidPreferencesTwo() public {
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](2);

        strategyDetailArray[0].actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();

        strategyDetailArray[0].data = abi.encode(uint256(block.timestamp));
        strategyDetailArray[1].data = abi.encode(uint256(2));

        _hevm.expectRevert();
        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            rebaseModuleMockContract.checkInputData(strategyDetailArray[i]);
        }
    }

    function testInputDataWithMultipleInValidPreferencesThree() public {
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](3);

        strategyDetailArray[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetailArray[1].actionName = rebaseModuleMockContract.TIME_PREFERENCE();
        strategyDetailArray[2].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        strategyDetailArray[2].data = abi.encode(uint256(120), uint256(0));
        strategyDetailArray[0].data = abi.encode(uint256(0));
        strategyDetailArray[1].data = abi.encode(uint256(block.timestamp));

        for (uint256 i = 0; i < strategyDetailArray.length; i++) {
            _hevm.expectRevert();
            rebaseModuleMockContract.checkInputData(strategyDetailArray[i]);
        }
    }

    // // _checkRebasePreferenceStrategies

    // function testGetPreferenceTicks() public {
    //     getStrategyKey(2000);
    //     console.logInt(strategyKey.tickLower);
    //     (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 20, 30);
    //     // positive ticks

    //     assertEq(tl, strategyKey.tickLower - 20);
    //     assertEq(tu, strategyKey.tickUpper + 30);
    //     assertEq(strategyKey.tickLower - 20 < strategyKey.tickLower, true);
    //     assertEq(strategyKey.tickUpper + 30 > strategyKey.tickUpper, true);

    //     // // negative ticks
    //     // poolContract = IUniswapV3Pool(poolAddressNegativeTicks);
    //     // getStrategyKey();
    //     // (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 20, 30);

    //     // assertEq(tl, strategyKey.tickLower - 20);
    //     // assertEq(tu, strategyKey.tickUpper + 30);
    //     // assertEq(strategyKey.tickLower - 20 < strategyKey.tickLower, true);
    //     // assertEq(strategyKey.tickUpper + 30 > strategyKey.tickUpper, true);
    // }

    // function testCheckRebasePreferenceStrategiesValidInputs() public {
    //     getStrategyKey(2000);
    //     // swapParams.tokenIn = address(token0);
    //     // swapParams.tokenOut = address(token1);
    //     // swapParams.fee = 500;
    //     // swapParams.recipient = owner;
    //     // swapParams.deadline = block.timestamp + 100;
    //     // swapParams.amountIn = 100;
    //     // swapParams.amountOutMinimum = 0;
    //     // swapParams.sqrtPriceLimitX96 = 0;
    //     // generateSwaps(swapParams);
    //     // bytes memory data = abi.encode(uint256(10), uint256(30));
    //     // (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
    //     // int24 tick = getTwap(strategyKey.pool);
    //     // bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data);
    //     // assertEq(success, (tick < tl || tick > tu));
    // }
}
