// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { AccessControl } from "../../base/AccessControl.sol";

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { ICLTTwapQuoter } from "../../interfaces/ICLTTwapQuoter.sol";
import { IExitStrategy } from "../../interfaces/modules/IExitStrategy.sol";

/// @title A51 Finance Autonomous Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice This contract is part of the A51 Finance platform, focusing on automated liquidity provision and rebalancing
/// strategies. The RebaseModule contract is responsible for validating and verifying the strategies before executing
/// them through CLTBase.
contract ExitModule is AccessControl, IExitStrategy {
    /// @notice The address of base contract
    ICLTBase public immutable cltBase;

    /// @notice The address of twap quoter
    ICLTTwapQuoter public twapQuoter;

    // 0xc5777e329881bb35c6de0a859435b42924520885cd50bf0a8cef6a1552361851
    bytes32 public constant EXIT_PREFERENCE = keccak256("EXIT_PREFERENCE");

    constructor(address _governance, address _baseContractAddress, address _twapQuoter) AccessControl(_governance) {
        twapQuoter = ICLTTwapQuoter(_twapQuoter);
        cltBase = ICLTBase(payable(_baseContractAddress));
    }

    function checkInputData(ICLTBase.StrategyPayload memory actionsData) external pure returns (bool) {
        bool hasExitPreference = actionsData.actionName == EXIT_PREFERENCE;
        if (hasExitPreference && isNonZero(actionsData.data)) {
            return true;
        }
        return false;
    }

    /// @notice Checks the bytes value is non zero or not.
    /// @param data bytes value to be checked.
    /// @return true if the value is nonzero.
    function isNonZero(bytes memory data) internal pure returns (bool) {
        uint256 dataLength = data.length;

        for (uint256 i = 0; i < dataLength; i++) {
            if (data[i] != bytes1(0)) {
                return true;
            }
        }

        return false;
    }
}
