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
    event UpgradesDisabled();
    event AdminPowerBurned();
    event AdminSet(address indexed newAdmin);
    event Initialized(
        address owner, string name, string symbol, uint8 decimals, address nft, uint96 amountPerNFT, address admin
    );

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
        __Pausable_init();
        __UUPSUpgradeable_init();

        require(amountPerNFT_ > 0, "NFTBackedToken: amountPerNFT is zero");

        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.decimals = decimals_;
        $.nft = IERC721(nft_);
        $.amountPerNFT = amountPerNFT_;
        $.admin = admin_;

        emit Initialized(owner_, name_, symbol_, decimals_, nft_, amountPerNFT_, admin_);
    }

    /**
     * @notice Deposits NFTs from the caller into the contract and mints ERC20s to the caller. The amount of ERC20s
     * per NFT is available by calling `amountPerNFT()`.
     * The caller must first approve the contract to transfer the NFTs on their behalf.
     * @param tokenIds Array of NFT ids to be deposited in the conract.
     * @return The amount of ERC20 tokens minted.
     */
    function deposit(uint256[] calldata tokenIds) external whenNotPaused returns (uint256) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokenIds.length; ++i) {
            $.nft.transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        uint256 erc20Amount = $.amountPerNFT * tokenIds.length;
        _mint(msg.sender, erc20Amount);

        emit Deposit(tokenIds, msg.sender);

        return erc20Amount;
    }

    /**
     * @notice Redeems the NFTs specified by `tokenIds` in exchange for burning the corresponding amount of ERC20 tokens.
     * The amount of ERC20s per NFT is available by calling `amountPerNFT()`.
     * @param tokenIds Array of NFT ids to be redeemed from the contract. They must be owned by this contract.
     * @return The amount of ERC20 tokens burned.
     */
    function redeem(uint256[] calldata tokenIds) external whenNotPaused returns (uint256) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokenIds.length; ++i) {
            $.nft.transferFrom(address(this), msg.sender, tokenIds[i]);
        }
        uint256 erc20Amount = $.amountPerNFT * tokenIds.length;
        _burn(msg.sender, erc20Amount);

        emit Redeem(tokenIds, msg.sender);

        return erc20Amount;
    }

    /**
     * @notice Swaps NFTs with ids `tokensIn` with `tokensOut`. The caller must approve the contract to transfer the
     * `tokensIn` NFTs on their behalf.
     * @param tokensIn Array of NFT ids to be sent to this contract.
     * @param tokensOut Array of NFTs ids to receive from this contract.
     */
    function swap(uint256[] calldata tokensIn, uint256[] calldata tokensOut) external whenNotPaused {
        require(tokensIn.length == tokensOut.length, "NFTBackedToken: length mismatch");
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();

        for (uint256 i; i < tokensIn.length; ++i) {
            $.nft.transferFrom(msg.sender, address(this), tokensIn[i]);
        }

        for (uint256 i; i < tokensOut.length; ++i) {
            $.nft.transferFrom(address(this), msg.sender, tokensOut[i]);
        }

        emit Swap(tokensIn, tokensOut, msg.sender);
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view virtual override returns (uint8) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.decimals;
    }

    /**
     * @notice The balance of redeemable NFTs for an account.
     * For example, if the amountPerNFT is 1M, and the account has 1.2M tokens, the redeemable balance is 1.
     */
    function redeemableNFTsBalance(address account) external view returns (uint256) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return balanceOf(account) / $.amountPerNFT;
    }

    /**
     * @notice The ERC721 token backing this ERC20 token.
     */
    function nft() external view returns (IERC721) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.nft;
    }

    /**
     * @notice The exchange rate between one backing NFT and this ERC20 contract, in ERC20's decimal units.
     */
    function amountPerNFT() external view returns (uint96) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.amountPerNFT;
    }

    /**
     * @notice The admin of this contract, which can pause and unpause the contract, and burn their admin power.
     */
    function admin() external view returns (address) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.admin;
    }

    /**
     * @notice Returns true if upgrades are disabled.
     */
    function upgradesDisabled() external view returns (bool) {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        return $.upgradesDisabled;
    }

    /**
     * @notice Disables upgrades of this contract. Once this is called, upgrades cannot be enabled again.
     * @dev Only the `owner` can call this function
     */
    function disableUpgrades() external onlyOwner {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.upgradesDisabled = true;

        emit UpgradesDisabled();
    }

    /**
     * @notice Sets the admin address who can pause/unpause the contract.
     * @dev Only `owner` or `admin` can call this.
     */
    function setAdmin(address newAdmin) external onlyOwnerOrAdmin {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.admin = newAdmin;

        emit AdminSet(newAdmin);
    }

    /**
     * @notice Sets the admin address to zero.
     * @dev Only `owner` or `admin` can call this.
     */
    function burnAdminPower() external onlyOwnerOrAdmin {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        $.admin = address(0);

        emit AdminPowerBurned();
    }

    /**
     * @notice Pauses the mint/redeem/swap functions.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpauses the mint/redeem/swap functions.
     */
    function unpause() external onlyOwnerOrAdmin {
        _unpause();
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {
        NFTBackedTokenStorage storage $ = _getNFTBackedTokenStorage();
        require(!$.upgradesDisabled, "upgrades disabled");
    }
}
