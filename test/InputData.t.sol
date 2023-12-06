// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

import { GovernanceFeeHandler } from "../src/GovernanceFeeHandler.sol";
import { RebaseModuleMock } from "./mocks/RebaseModule.mock.sol";
import { ModeTicksCalculation } from "../src/base/ModeTicksCalculation.sol";
import { Vm } from "forge-std/Vm.sol";
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

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        if (address(token0) >= address(token1)) {
            (token0, token1) = (token1, token0);
        }

        token0.mint(owner, 10_000_000_000e18);
        token1.mint(owner, 10_000_000_000e18);

        // intialize uniswap contracts
        weth = new WETH();
        uniswapV3FactoryContract = IUniswapV3Factory(deployUniswapV3Factory());
        poolContract = IUniswapV3Pool(uniswapV3FactoryContract.createPool(address(token0), address(token1), 500));
        poolContract.initialize(TickMath.getSqrtRatioAtTick(0));
        router = new SwapRouter(address(uniswapV3FactoryContract), address(weth));
        positionManager = new
    NonfungiblePositionManager(address(uniswapV3FactoryContract),address(weth),address(uniswapV3FactoryContract));

        mintParams.token0 = address(token0);
        mintParams.token1 = address(token1);
        mintParams.tickLower = (-600_000 / poolContract.tickSpacing()) * poolContract.tickSpacing();
        mintParams.tickUpper = (600_000 / poolContract.tickSpacing()) * poolContract.tickSpacing();
        mintParams.fee = 500;
        mintParams.recipient = owner;
        mintParams.amount0Desired = 1000e18;
        mintParams.amount1Desired = 100e18;
        mintParams.amount0Min = 0;
        mintParams.amount1Min = 0;
        mintParams.deadline = 2_000_000_000;

        token0.approve(address(positionManager), type(uint256).max);
        token1.approve(address(positionManager), type(uint256).max);

        positionManager.mint(mintParams);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(address(this), feeParams, feeParams);

        // initialize base contract
        baseContract = new CLTBase("ALP Base", "ALP", owner, address(0), address(feeHandler), uniswapV3FactoryContract);

        // approve tokens
        token0.approve(address(baseContract), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(baseContract), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        generateMultipleSwapsWithTime();

        poolContract.increaseObservationCardinalityNext(80);
        // initialize module contract
        rebaseModuleMockContract = new RebaseModuleMock(owner,address(baseContract));
    }

    function depositInRangeLiquidity(ICLTBase.PositionActions memory positionActions)
        public
        returns (bytes32 strategyID)
    {
        positionActions.mode = positionActions.mode;
        positionActions.exitStrategy = positionActions.exitStrategy;
        positionActions.rebaseStrategy = positionActions.rebaseStrategy;
        positionActions.liquidityDistribution = positionActions.liquidityDistribution;

        getStrategyKey(2000);

        _hevm.prank(owner);
        baseContract.toggleOperator(address(this));

        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModuleMockContract), true
        );

        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModuleMockContract), true
        );

        baseContract.createStrategy(strategyKey, positionActions, 0, 0, true, false);

        // check if strategy is created
        strategyID = keccak256(abi.encode(address(this), 1));
        (ICLTBase.StrategyKey memory key, address _owner,,, bool isCompound,,,,) = baseContract.strategies(strategyID);
        assertEq(key.tickLower, strategyKey.tickLower);
        assertEq(key.tickUpper, strategyKey.tickUpper);
        assertEq(address(this), _owner);
        assertEq(isCompound, true);

        // deposit
        ICLTBase.DepositParams memory depositParams;
        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);

        baseContract.deposit(depositParams);
    }

    function generateMultipleSwapsWithTime() public {
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, 500, owner, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, 500, owner, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, 500, owner, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, 500, owner, 5e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
    }

    function executeSwap(
        ERC20Mock tokenIn,
        ERC20Mock tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    )
        public
    {
        ISwapRouter.ExactInputSingleParams memory swapParams;

        swapParams.tokenIn = address(tokenIn);
        swapParams.tokenOut = address(tokenOut);
        swapParams.fee = fee;
        swapParams.recipient = recipient;
        swapParams.deadline = block.timestamp + 100;
        swapParams.amountIn = amountIn;
        swapParams.amountOutMinimum = amountOutMinimum;
        swapParams.sqrtPriceLimitX96 = sqrtPriceLimitX96;

        router.exactInputSingle(swapParams);
    }

    function CheckPosition() public view returns (bool) {
        (, int24 tick,,,,,) = poolContract.slot0();

        if (tick < strategyKey.tickLower || tick > strategyKey.tickUpper) {
            return true;
        }
        return false;
    }

    function getStrategyKey(int24 difference) public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick, poolContract.tickSpacing());
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

    function getNewTicks(
        uint256 mode,
        int24 tickLower,
        int24 tickUpper
    )
        public
        view
        returns (int24 newLowerTick, int24 newUpperTick)
    {
        int24 tickSpacing = poolContract.tickSpacing();

        (, int24 currentTick,,,,,) = poolContract.slot0();
        currentTick = floorTick(currentTick, tickSpacing);

        if (mode == 1) {
            // mode = 1 (shift right)
            newLowerTick = currentTick + tickSpacing;
            newUpperTick =
                floorTick(newLowerTick + ((currentTick - tickLower) + (tickUpper - currentTick)), tickSpacing);
        } else if (mode == 2) {
            // mode = 2 (shift right)
            newUpperTick = currentTick - tickSpacing;
            newLowerTick =
                floorTick(newUpperTick - ((currentTick - tickLower) + (tickUpper - currentTick)), tickSpacing);
        } else if (mode == 3) {
            if (currentTick > tickUpper) {
                // mode = 2 (shift right)
                newUpperTick = currentTick - tickSpacing;
                newLowerTick =
                    floorTick(newUpperTick - ((currentTick - tickLower) + (tickUpper - currentTick)), tickSpacing);
            } else {
                // mode = 1 (shift right)
                newLowerTick = currentTick + tickSpacing;
                newUpperTick =
                    floorTick(newLowerTick + ((currentTick - tickLower) + (tickUpper - currentTick)), tickSpacing);
            }
        }
    }

    // checkStrategiesArray Testing

    function testEmptyArrayReverts() public {
        bytes32[] memory data = new bytes32[](1);
        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", data[0]);
        vm.expectRevert(encodedError);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    function testArrayWithDuplicatesReverts() public {
        bytes32 duplicateId = keccak256("strategy1");
        bytes32[] memory data = new bytes32[](2);
        data[0] = duplicateId;
        data[1] = duplicateId;
        // bytes memory encodedError = abi.encodeWithSignature("DuplicateStrategyId(bytes32)", duplicateId);
        vm.expectRevert();
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    function testArrayWithAllElementsZeroReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(0);
        data[1] = bytes32(0);
        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", data[1]);
        vm.expectRevert(encodedError);
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    function testArrayWithAllElementsIdenticalReverts() public {
        bytes32 identicalId = keccak256(abi.encodePacked("strategy"));
        bytes32[] memory data = new bytes32[](3);
        data[0] = identicalId;
        data[1] = identicalId;
        data[2] = identicalId;
        // bytes memory encodedError = abi.encodeWithSignature("DuplicateStrategyId(bytes32)", identicalId);
        vm.expectRevert();
        rebaseModuleMockContract.checkStrategiesArray(data);
    }

    /*
     * check input data test cases
     */

    // Price Preference
    function test_fuzz_pricePreferenceWithValidInputs(uint256 amount0, uint256 amount1) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        vm.assume(amount0 > 0 && amount0 < 8_388_608 && amount1 < 8_388_608 && amount1 > 0);
        strategyDetail.data = abi.encode(uint256(amount0), uint256(amount1));
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function test_fuzz_pricePreferenceWithLowerPriceZero(uint256 amount1) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        vm.assume(amount1 < 8_388_608 && amount1 > 0);
        strategyDetail.data = abi.encode(uint256(0), uint256(30));
        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        _hevm.expectRevert(selector);
        rebaseModuleMockContract.checkInputData(strategyDetail);
    }

    function test_fuzz_pricePreferenceWithUpperPriceZero(uint256 amount0) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.PRICE_PREFERENCE();

        vm.assume(amount0 < 8_388_608 && amount0 > 0);
        strategyDetail.data = abi.encode(uint256(amount0), uint256(0));
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

    // Rebase Inactivity

    function testInputDataRebaseInActivityWithValidInputs(uint256 amount) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        vm.assume(amount > 0);
        strategyDetail.data = abi.encode(uint256(amount));
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

    function testInputDataWithValidFuzzing(uint256 _actionIndex, uint256 _value1, uint256 _value2) public {
        uint256 arrayLength = _actionIndex % 3 + 1; // to ensures length is always between 1 and 3
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](arrayLength);

        for (uint256 i = 0; i < arrayLength; i++) {
            if (i % 2 == 0) {
                vm.assume(_value1 > 0);
                strategyDetailArray[i].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
                strategyDetailArray[i].data = abi.encode(_value1);
            } else if (i % 2 == 1) {
                vm.assume(_value1 > 0 && _value1 < 8_388_608 && _value2 < 8_388_608 && _value2 > 0);
                strategyDetailArray[i].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
                strategyDetailArray[i].data = abi.encode(_value1, _value2);
            }
        }

        for (uint256 i = 0; i < arrayLength; i++) {
            assertTrue(rebaseModuleMockContract.checkInputData(strategyDetailArray[i]));
        }
    }

    function testInputDataWithInvalidFuzzing(uint256 _actionIndex, uint256 _value1, uint256 _value2) public {
        // Define the array length based on fuzzed value
        uint256 arrayLength = _actionIndex % 3 + 1; // Ensures length is always between 1 and 3
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](arrayLength);

        // Fuzzing different action names with intentionally invalid data
        for (uint256 i = 0; i < arrayLength; i++) {
            if (i % 2 == 0) {
                vm.assume(_value1 <= 0);
                strategyDetailArray[i].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
                strategyDetailArray[i].data = abi.encode(0);
            } else if (i % 2 == 1) {
                vm.assume(_value1 <= 0 && _value2 <= 0);
                strategyDetailArray[i].actionName = rebaseModuleMockContract.PRICE_PREFERENCE();
                strategyDetailArray[i].data = abi.encode(_value1, _value2);
            }
        }

        for (uint256 i = 0; i < arrayLength; i++) {
            _hevm.expectRevert();
            rebaseModuleMockContract.checkInputData(strategyDetailArray[i]);
        }
    }

    // _getPreferenceTicks
    function testGetPreferenceTicks(int24 lpd, int24 upd) public {
        getStrategyKey(2000);
        vm.assume(lpd > 0 && lpd < 887_272 && upd < 887_272 && upd > 0);
        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            rebaseModuleMockContract._getPreferenceTicks(strategyKey, lpd, upd);
        assertTrue(upperPreferenceTick > lowerPreferenceTick);
    }

    // _checkRebasePreferenceStrategies

    // function testCheckRebasePreferenceStrategiesValidInputs() public {
    //     getStrategyKey(2000);
    //     bytes memory data = abi.encode(uint256(10), uint256(30));
    //     (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
    //     int24 tick = getTwap(strategyKey.pool);
    //     bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, 2);
    //     assertEq(success, (tick < tl || tick > tu));

    //     _hevm.warp(block.timestamp + 3600);
    //     _hevm.roll(block.number + 30);

    //     executeSwap(token1, token0, 500, owner, 80e18, 0, 0);

    //     _hevm.warp(block.timestamp + 3600);
    //     _hevm.roll(block.number + 30);

    //     (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
    //     tick = getTwap(strategyKey.pool);
    //     success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, 3);
    //     assertEq(success, (tick < tl || tick > tu));
    // }

    function testCheckRebasePreferenceStrategiesWithMode1Fuzzing(
        int24 _lowerPreferenceDiff,
        int24 _upperPreferenceDiff
    )
        public
    {
        vm.assume(_lowerPreferenceDiff > 0 && _upperPreferenceDiff > 0);
        vm.assume(_lowerPreferenceDiff < 887_272 && _upperPreferenceDiff < 887_272);
        uint256 _mode = 1;

        getStrategyKey(2000);
        bytes memory data = abi.encode(_lowerPreferenceDiff, _upperPreferenceDiff);

        (int24 tl, int24 tu) =
            rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        int24 tick = getTwap(strategyKey.pool);
        bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        executeSwap(token0, token1, 500, owner, 80e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        tick = getTwap(strategyKey.pool);
        success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));
    }

    function testCheckRebasePreferenceStrategiesWithMode2Fuzzing(
        int24 _lowerPreferenceDiff,
        int24 _upperPreferenceDiff
    )
        public
    {
        vm.assume(_lowerPreferenceDiff > 0 && _upperPreferenceDiff > 0);
        vm.assume(_lowerPreferenceDiff < 887_272 && _upperPreferenceDiff < 887_272);
        uint256 _mode = 2;

        getStrategyKey(2000);
        bytes memory data = abi.encode(_lowerPreferenceDiff, _upperPreferenceDiff);

        (int24 tl, int24 tu) =
            rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        int24 tick = getTwap(strategyKey.pool);
        bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        executeSwap(token1, token0, 500, owner, 80e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        tick = getTwap(strategyKey.pool);
        success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));
    }

    function testCheckRebasePreferenceStrategiesWithMode3Fuzzing(
        int24 _lowerPreferenceDiff,
        int24 _upperPreferenceDiff
    )
        public
    {
        vm.assume(_lowerPreferenceDiff > 0 && _upperPreferenceDiff > 0);
        vm.assume(_lowerPreferenceDiff < 887_272 && _upperPreferenceDiff < 887_272);
        uint256 _mode = 3;

        getStrategyKey(2000);
        bytes memory data = abi.encode(_lowerPreferenceDiff, _upperPreferenceDiff);

        (int24 tl, int24 tu) =
            rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        int24 tick = getTwap(strategyKey.pool);
        bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        executeSwap(token1, token0, 500, owner, 80e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, _lowerPreferenceDiff, _upperPreferenceDiff);
        tick = getTwap(strategyKey.pool);
        success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, _mode);
        assertEq(success, (tick < tl || tick > tu));
    }

    function testCheckRebasePreferenceStrategiesWithALargeSwapOnTwap() public {
        getStrategyKey(2000);
        bytes memory data = abi.encode(uint256(10), uint256(30));
        (int24 tl, int24 tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
        int24 tick = getTwap(strategyKey.pool);
        bool success = rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, 1);
        assertEq(success, (tick < tl || tick > tu));

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);

        executeSwap(token1, token0, 500, owner, 80e18, 0, 0);

        (tl, tu) = rebaseModuleMockContract._getPreferenceTicks(strategyKey, 10, 30);
        tick = getTwap(strategyKey.pool);
        assertFalse(rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, 1));
        assertEq(
            rebaseModuleMockContract._checkRebasePreferenceStrategies(strategyKey, data, 1), (tick < tl || tick > tu)
        );
    }

    // _checkRebaseInactivityStrategies
    function testCheckRebaseInactivityStrategiesWithInValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;

        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(7));
        bytes memory actionStatus = "";

        assertTrue(rebaseModuleMockContract._checkRebaseInactivityStrategies(strategyDetail, actionStatus));
    }

    function testCheckRebaseInactivityStrategiesWithGreaterActionStatus() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(5));
        bytes memory actionStatus = abi.encode(uint256(5));
        assertFalse(rebaseModuleMockContract._checkRebaseInactivityStrategies(strategyDetail, actionStatus));
    }

    function testCheckRebaseInactivityStrategiesFuzzing(uint256 status, uint256 data) public {
        vm.assume(status >= 0 && status <= 10 ** 18);
        vm.assume(data >= 0 && data <= 10 ** 18);
        bytes memory preferredInActivity = abi.encode(uint256(data));
        bytes memory actionStatus = abi.encode(uint256(status));

        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.data = preferredInActivity;
        if (data > 10 && data < 1000) {
            actionStatus = "";
        }

        bool result = rebaseModuleMockContract._checkRebaseInactivityStrategies(strategyDetail, actionStatus);

        if (actionStatus.length > 0) {
            uint256 rebaseCount = abi.decode(actionStatus, (uint256));
            uint256 preferredInActivityInternal = abi.decode(preferredInActivity, (uint256));
            assertFalse(
                (rebaseCount > 0 && preferredInActivityInternal == rebaseCount) == result,
                "The function output does not match the expected result."
            );
        } else {
            assertTrue(result, "Function should return false when rebaseOptions length is 0.");
        }
    }
}
