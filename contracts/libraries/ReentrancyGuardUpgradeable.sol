// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

abstract contract ReentrancyGuardUpgradeable is Initializable {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    struct ReentrancyGuardStorage {
        uint256 status;
    }

    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        keccak256(abi.encode(uint256(keccak256("aralys.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff));

    function __ReentrancyGuard_init() internal onlyInitializing {
        _getReentrancyGuardStorage().status = NOT_ENTERED;
    }

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        bytes32 slot = REENTRANCY_GUARD_STORAGE;
        assembly {
            $.slot := slot
        }
    }

    modifier nonReentrant() {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        require($.status != ENTERED, "ReentrancyGuard: reentrant call");
        $.status = ENTERED;
        _;
        $.status = NOT_ENTERED;
    }
}
