// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC721 } from "./libs/IERC721.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract NFTBackedToken is ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    event Deposit(uint256[] tokenIds, address indexed to);
    event Redeem(uint256[] tokenIds, address indexed to);
    event Swap(uint256[] tokensIn, uint256[] tokensOut, address indexed to);

    /// @custom:storage-location erc7201:nouns.storage.NFTBackedToken
    struct NFTBackedTokenStorage {
        IERC721 nft;
        uint96 amountPerNFT;
        address admin;
        uint8 decimals;
        bool upgradesDisabled;
    }

    // keccak256(abi.encode(uint256(keccak256("nouns.storage.NFTBackedToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NFTBackedTokenStorageLocation =
        0xaad48c25d976bddae43806613caf4683472e13f174a999da79654799a1b85f00;

    function _getNFTBackedTokenStorage() private pure returns (NFTBackedTokenStorage storage $) {
        assembly {
            $.slot := NFTBackedTokenStorageLocation
        }
    }

    modifier onlyOwnerOrAdmin() {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        require(msg.sender == $.admin || msg.sender == owner(), "must be admin or owner");
        _;
    }

    modifier onlyAdmin() {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        require(msg.sender == $.admin, "must be admin");
        _;
    }

    constructor() initializer { }

    /**
     *
     * @param owner_ the owner of this contract, which can upgrade the contract.
     * @param name_  the name of the ERC20 token.
     * @param symbol_  the symbol of the ERC20 token.
     * @param decimals_ the decimals of the ERC20 token.
     * @param nft_ the ERC721 token backing this ERC20 token.
     * @param amountPerNFT_ the amount of ERC20 token minted per NFT, adjusted to its decimals; for example, if
     * decimals is 18, and amountPerNFT is 1_000_000, then this parameter's value should be 1M * 10^18.
     */
    function initialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address nft_,
        uint96 amountPerNFT_,
        address admin_
    ) public initializer {
        __Ownable_init(owner_);
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);

        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.decimals = decimals_;
        $.nft = IERC721(nft_);
        $.amountPerNFT = amountPerNFT_;
        $.admin = admin_;
    }

    function deposit(uint256[] calldata tokenIds, address to) public whenNotPaused {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokenIds.length; ++i) {
            $.nft.transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        _mint(to, $.amountPerNFT * tokenIds.length);

        emit Deposit(tokenIds, to);
    }

    function redeem(uint256[] calldata tokenIds, address to) public whenNotPaused {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokenIds.length; ++i) {
            $.nft.transferFrom(address(this), to, tokenIds[i]);
        }
        _burn(msg.sender, $.amountPerNFT * tokenIds.length);

        emit Redeem(tokenIds, to);
    }

    function swap(uint256[] calldata tokensIn, uint256[] calldata tokensOut, address to) public whenNotPaused {
        require(tokensIn.length == tokensOut.length, "NFTBackedToken: length mismatch");
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokensIn.length; ++i) {
            $.nft.transferFrom(msg.sender, address(this), tokensIn[i]);
        }

        for (uint256 i; i < tokensOut.length; ++i) {
            $.nft.transferFrom(address(this), to, tokensOut[i]);
        }

        emit Swap(tokensIn, tokensOut, to);
    }

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.decimals;
    }

    function redeemableNFTsBalance(address account) public view returns (uint256) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return balanceOf(account) / $.amountPerNFT;
    }

    function nft() public view returns (IERC721) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.nft;
    }

    function amountPerNFT() public view returns (uint96) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.amountPerNFT;
    }

    function admin() public view returns (address) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.admin;
    }

    function upgradesDisabled() public view returns (bool) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.upgradesDisabled;
    }

    function disableUpgrades() public onlyOwner {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.upgradesDisabled = true;
    }

    function burnAdminPower() public onlyOwnerOrAdmin {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.admin = address(0);
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyOwnerOrAdmin {
        _unpause();
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        require(!$.upgradesDisabled, "upgrades disabled");
    }
}
