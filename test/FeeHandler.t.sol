// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Test } from "forge-std/Test.sol";
import { Fixtures } from "./utils/Fixtures.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { ICLTModules } from "../src/interfaces/ICLTModules.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

contract FeeHandlerTest is Test, Fixtures {
    event PublicFeeRegistryUpdated(IGovernanceFeeHandler.ProtocolFeeRegistry newRegistry);
    event PrivateFeeRegistryUpdated(IGovernanceFeeHandler.ProtocolFeeRegistry newRegistry);

    function setUp() public {
        deployFreshState();
    }

    function test_feeHandler_revertsIfNotOwner() public {
        vm.startPrank(msg.sender);
        vm.expectRevert("UNAUTHORIZED");
        feeHandler.setPrivateFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0.4 ether,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        vm.expectRevert("UNAUTHORIZED");
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0.4 ether,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );
        vm.stopPrank();
    }

    function test_feeHandler_revertsIfMaxProtocolFeeOnManagementFee() public {
        vm.expectRevert("ManagementFeeLimitExceed");
        feeHandler.setPrivateFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0.6 ether, // 60%
                protcolFeeOnPerformance: 0
            })
        );

        vm.expectRevert("ManagementFeeLimitExceed");
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0.6 ether, // 60%
                protcolFeeOnPerformance: 0
            })
        );
    }

    function test_feeHandler_revertsIfMaxProtocolFeeOnPerformanceFee() public {
        vm.expectRevert("PerformanceFeeLimitExceed");
        feeHandler.setPrivateFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0.6 ether
            })
        );

        vm.expectRevert("PerformanceFeeLimitExceed");
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0.6 ether
            })
        );
    }

    function test_feeHandler_revertsIfMaxProtocolAutomationFee() public {
        vm.expectRevert("LPAutomationFeeLimitExceed");
        feeHandler.setPrivateFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0.6 ether,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        vm.expectRevert("LPAutomationFeeLimitExceed");
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0.6 ether,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );
    }

    function test_feeHandler_revertsIfMaxProtocolStrategyCreationFee() public {
        vm.expectRevert("StrategyFeeLimitExceed");
        feeHandler.setPrivateFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 2 ether,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        vm.expectRevert("StrategyFeeLimitExceed");
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 2 ether,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );
    }

    function test_feeHandler_succeedCorrectEventParams() public {
        IGovernanceFeeHandler.ProtocolFeeRegistry memory newRegistry = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0.1 ether,
            strategyCreationFee: 0.3 ether,
            protcolFeeOnManagement: 0.24 ether,
            protcolFeeOnPerformance: 0.16 ether
        });

        vm.expectEmit();
        emit PrivateFeeRegistryUpdated(newRegistry);
        feeHandler.setPrivateFeeRegistry(newRegistry);

        vm.expectEmit();
        emit PublicFeeRegistryUpdated(newRegistry);
        feeHandler.setPublicFeeRegistry(newRegistry);
    }

    function test_feeHandler_succeedCorrectState() public {
        IGovernanceFeeHandler.ProtocolFeeRegistry memory newRegistry = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0.1 ether,
            strategyCreationFee: 0.3 ether,
            protcolFeeOnManagement: 0.24 ether,
            protcolFeeOnPerformance: 0.16 ether
        });

        feeHandler.setPublicFeeRegistry(newRegistry);
        feeHandler.setPrivateFeeRegistry(newRegistry);

        uint256 lpAutomationFee;
        uint256 strategyCreationFee;
        uint256 protcolFeeOnManagement;
        uint256 protcolFeeOnPerformance;

        (lpAutomationFee, strategyCreationFee, protcolFeeOnManagement, protcolFeeOnPerformance) =
            feeHandler.getGovernanceFee(true);

        assertEq(lpAutomationFee, newRegistry.lpAutomationFee);
        assertEq(strategyCreationFee, newRegistry.strategyCreationFee);
        assertEq(protcolFeeOnManagement, newRegistry.protcolFeeOnManagement);
        assertEq(protcolFeeOnPerformance, newRegistry.protcolFeeOnPerformance);

        (lpAutomationFee, strategyCreationFee, protcolFeeOnManagement, protcolFeeOnPerformance) =
            feeHandler.getGovernanceFee(false);

        assertEq(lpAutomationFee, newRegistry.lpAutomationFee);
        assertEq(strategyCreationFee, newRegistry.strategyCreationFee);
        assertEq(protcolFeeOnManagement, newRegistry.protcolFeeOnManagement);
        assertEq(protcolFeeOnPerformance, newRegistry.protcolFeeOnPerformance);
    }
}
