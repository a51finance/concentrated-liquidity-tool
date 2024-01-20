// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Owned } from "../../lib/solmate/src/auth/Owned.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";

abstract contract AccessControl is Owned, Pausable {
    mapping(address => bool) internal _operatorApproved;

    modifier onlyOperator() {
        require(_operatorApproved[msg.sender]);
        _;
    }

    constructor(address _owner) Owned(_owner) { }

    /// @notice Updates the status of given account as operator
    /// @dev Must be called by the current governance
    /// @param _operator Account to update status
    function toggleOperator(address _operator) external onlyOwner {
        _operatorApproved[_operator] = !_operatorApproved[_operator];
    }

    /// @notice Returns the status for a given operator that can execute operations
    /// @param _operator Account to check status
    function isOperator(address _operator) external view returns (bool) {
        return _operatorApproved[_operator];
    }

    /// @dev Triggers stopped state.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Returns to normal state.
    function unpause() external onlyOwner {
        _unpause();
    }
}
