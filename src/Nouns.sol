// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20PermitUpgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import { IERC721 } from './libs/IERC721.sol';
import { UUPSUpgradeable } from './libs/UUPSUpgradeable.sol';

contract Nouns is ERC20PermitUpgradeable, UUPSUpgradeable {

    uint256 public constant MULTIPLIER = 1_000_000 * 1e18;

    IERC721 public immutable nounsToken;

    address public owner;

    constructor(address nounsToken_) initializer {
        nounsToken = IERC721(nounsToken_);
    }

    function initialize(address owner_) public initializer {
        owner = owner_;
        __ERC20_init("Nouns", "NOUNS");
        __ERC20Permit_init("Nouns");
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert('OnlyOwner');
        _;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    
    function mint(uint256[] calldata nounIds, address to) public {
        for (uint256 i; i < nounIds.length; ++i) {
            nounsToken.transferFrom(msg.sender, address(this), nounIds[i]);
        }
        _mint(to, MULTIPLIER * nounIds.length);
    }

    function redeem(uint256[] calldata nounIds, address to) public {
        for (uint256 i; i < nounIds.length; ++i) {
            nounsToken.transferFrom(address(this), to, nounIds[i]);
        }
        _burn(msg.sender, MULTIPLIER * nounIds.length);
    }
}
