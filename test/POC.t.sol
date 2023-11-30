// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IPreference } from "../src/interfaces/modules/IPreference.sol";

import { RebaseModuleMock } from "./mocks/RebaseModule.mock.sol";
import { ModeTicksCalculation } from "../src/base/ModeTicksCalculation.sol";
import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { console } from "forge-std/console.sol";

import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { UniswapDeployer } from "./lib/UniswapDeployer.sol";
import { NonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract POC is Test, UniswapDeployer {
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
    address alice = _hevm.addr(1);
    address bob = _hevm.addr(2);

    address owner = address(this);

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        if (address(token0) >= address(token1)) {
            (token0, token1) = (token1, token0);
        }

        token0.mint(owner, 10_000_000_000e18);
        token1.mint(owner, 10_000_000_000e18);

        token0.mint(alice, 10_000_000_000e18);
        token1.mint(alice, 10_000_000_000e18);

        token0.mint(bob, 10_000_000_000e18);
        token1.mint(bob, 10_000_000_000e18);

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

        // initialize base contract
        baseContract = new CLTBase("ALP Base", "ALP", owner, address(0), 1000000000000000, uniswapV3FactoryContract);

        // approve tokens
        token0.approve(address(baseContract), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(baseContract), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        _hevm.startPrank(alice);
        token0.approve(address(baseContract), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(baseContract), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        _hevm.stopPrank();

        _hevm.startPrank(bob);
        token0.approve(address(baseContract), type(uint256).max);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(baseContract), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        _hevm.stopPrank();

        generateMultipleSwapsWithTime();

        poolContract.increaseObservationCardinalityNext(80);
        // initialize module contract
        rebaseModuleMockContract = new RebaseModuleMock(owner,address(baseContract));

        baseContract.toggleOperator(address(this));

        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModuleMockContract), true
        );

        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModuleMockContract), true
        );
    }

    function generateMultipleSwapsWithTime() public {
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token0, token1, 500, owner, 10e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.number + 30);
        executeSwap(token1, token0, 500, owner, 10e18, 0, 0);
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

    function getStrategyKey(int24 difference) public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick - difference, poolContract.tickSpacing());
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

    function testPOC() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModuleMockContract.REBASE_INACTIVITY();
        rebaseActions[0].data = abi.encode(3);

        ICLTBase.PositionActions memory positionActions;

        getStrategyKey(1000);

        positionActions.mode = 1;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        baseContract.createStrategy(strategyKey, positionActions, 0, false, true);

        ICLTBase.DepositParams memory depositParams;

        depositParams.strategyId = keccak256(abi.encode(address(this), 1));
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = alice;

        _hevm.prank(alice);
        baseContract.deposit(depositParams);

        executeSwap(token0, token1, 500, address(this), 10e18, 0, 0);
        executeSwap(token1, token0, 500, address(this), 10e18, 0, 0);

        // user 2

        baseContract.createStrategy(strategyKey, positionActions, 0, true, true);

        depositParams.strategyId = keccak256(abi.encode(address(this), 2));
        depositParams.amount0Desired = 10e18;
        depositParams.amount1Desired = 10e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = bob;

        _hevm.prank(bob);
        baseContract.deposit(depositParams);

        // executeSwap(token0, token1, 500, address(this), 20e18, 0, 0);
        // executeSwap(token1, token0, 500, address(this), 20e18, 0, 0);

        _hevm.prank(address(baseContract));
        poolContract.burn(strategyKey.tickLower, strategyKey.tickUpper, 0);

        // alice

        (,,, uint128 fee0, uint128 fee1) = poolContract.positions(
            keccak256(abi.encodePacked(address(baseContract), strategyKey.tickLower, strategyKey.tickUpper))
        );

        (, uint256 liquidityShareAlice,,,,) = baseContract.positions(1);
        (, uint256 liquidityShareBob,,,,) = baseContract.positions(2);

        console.log("===============Alice (no Compound)===============");
        console.log("Strategy ID");
        console.logBytes32(keccak256(abi.encode(address(this), 1)));
        console.log("Upper Tick");
        console.logInt(strategyKey.tickUpper);
        console.log("Lower Tick");
        console.logInt(strategyKey.tickLower);
        console.log("Alice Deposit token0", 100e18);
        console.log("Alice Deposit token1", 100e18);
        console.log("Alice Share", liquidityShareAlice);

        console.log("===============Bob (Compound)===============");
        console.log("Strategy ID");
        console.logBytes32(keccak256(abi.encode(address(this), 2)));
        console.log("Upper Tick");
        console.logInt(strategyKey.tickUpper);
        console.log("Lower Tick");
        console.logInt(strategyKey.tickLower);
        console.log("Bob Deposit token0", 10e18);
        console.log("Bob Deposit token1", 10e18);
        console.log("Bob Share", liquidityShareBob);

        console.log("=============================================");

        console.log("Total Fees 0", fee0);
        console.log("Total Fees 1", fee1);

        console.log("===============Bob Withdraws===============");

        _hevm.prank(bob);
        baseContract.withdraw(
            ICLTBase.WithdrawParams({ tokenId: 2, liquidity: liquidityShareBob, recipient: bob, refundAsETH: true })
        );

        _hevm.prank(address(baseContract));
        (,,, fee0, fee1) = poolContract.positions(
            keccak256(abi.encodePacked(address(baseContract), strategyKey.tickLower, strategyKey.tickUpper))
        );

        console.log("Total Fees 0 after bob withdraws:", fee0);
        console.log("Total Fees 1 after bob withdraws:", fee1);
    }
}
