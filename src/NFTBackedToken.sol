// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC721 } from "./libs/IERC721.sol";
import { UUPSUpgradeable } from "./libs/UUPSUpgradeable.sol";

contract NFTBackedToken is ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    IERC721 public nft;
    uint8 public decimals_;
    uint88 public unitsPerNFT;

    function initialize(
        address nft_,
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals__,
        uint88 unitsPerNFT_
    ) public initializer {
        nft = IERC721(nft_);
        decimals_ = decimals__;
        unitsPerNFT = unitsPerNFT_;
        __Ownable_init(owner_);
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
    }

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return decimals_;
    }

    function deposit(uint256[] calldata tokenIds, address to) public {
        for (uint256 i; i < tokenIds.length; ++i) {
            nft.transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        _mint(to, unitsPerNFT * (10 ** decimals_) * tokenIds.length);
    }

    function redeem(uint256[] calldata tokenIds, address to) public {
        for (uint256 i; i < tokenIds.length; ++i) {
            nft.transferFrom(address(this), to, tokenIds[i]);
        }
        _burn(msg.sender, unitsPerNFT * (10 ** decimals_) * tokenIds.length);
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
