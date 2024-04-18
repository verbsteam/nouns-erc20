// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC721 } from "./libs/IERC721.sol";
import { UUPSUpgradeable } from "./libs/UUPSUpgradeable.sol";
// we can probably use UUPSUpgradeable from OZ instead of solady? I used the solady one before bringing OZ as a dependency
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract NFTBackedToken is
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    IERC721 public nft;
    uint8 public decimals_;
    uint88 public amountPerNFT; // with 18 decimals, the max number here is ~309M. should we make this variable larger?
    bool public upgradesDisabled;
    address public admin;
    // do we want to use a keccak based location for easier future upgrades?

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == admin || msg.sender == owner(), "must be admin or owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "must be admin");
        _;
    }

    // NFTBackedToken needs a constructor with initializer

    /**
     *
     * @param owner_ the owner of this contract, which can upgrade the contract.
     * @param name_  the name of the ERC20 token.
     * @param symbol_  the symbol of the ERC20 token.
     * @param decimals__ the decimals of the ERC20 token.
     * @param nft_ the ERC721 token backing this ERC20 token.
     * @param amountPerNFT_ the amount of ERC20 token minted per NFT, adjusted to its decimals; for example, if
     * decimals is 18, and amountPerNFT is 1_000_000, then this parameter's value should be 1M * 10^18.
     */
    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals__,
        address nft_,
        uint88 amountPerNFT_,
        address admin_
    ) public initializer {
        __Ownable_init(owner_);
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_); // do we want to add some test for the permit? or no need?
        decimals_ = decimals__;
        nft = IERC721(nft_);
        amountPerNFT = amountPerNFT_;
        admin = admin_;
    }

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return decimals_;
    }

    function deposit(uint256[] calldata tokenIds, address to) public whenNotPaused {
        for (uint256 i; i < tokenIds.length; ++i) {
            nft.transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        _mint(to, amountPerNFT * tokenIds.length);
    }

    function redeem(uint256[] calldata tokenIds, address to) public whenNotPaused {
        for (uint256 i; i < tokenIds.length; ++i) {
            nft.transferFrom(address(this), to, tokenIds[i]);
        }
        _burn(msg.sender, amountPerNFT * tokenIds.length);
    }

    function swap(uint256[] calldata tokensIn, uint256[] calldata tokensOut, address to)
        public
        whenNotPaused
    {
        require(tokensIn.length == tokensOut.length, "NFTBackedToken: length mismatch");

        for (uint256 i; i < tokensIn.length; ++i) {
            nft.transferFrom(msg.sender, address(this), tokensIn[i]);
            nft.transferFrom(address(this), to, tokensOut[i]);
        }
    }

    function balanceToBackingNFTCount(address account) public view returns (uint256) {
        return balanceOf(account) / amountPerNFT;
    }

    function disableUpgrades() public onlyOwner {
        upgradesDisabled = true;
    }

    function burnAdminPower() public onlyOwnerOrAdmin {
        admin = address(0);
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyOwnerOrAdmin {
        _unpause();
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {
        require(!upgradesDisabled, "upgrades disabled");
    }
}
