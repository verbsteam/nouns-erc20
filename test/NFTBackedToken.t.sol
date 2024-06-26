// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { NFTBackedToken } from "../src/NFTBackedToken.sol";
import { TokenDeployer } from "../src/TokenDeployer.sol";
import { IERC721 } from "../src/libs/IERC721.sol";
import { LibClone } from "../src/libs/LibClone.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { SigUtils } from "./SigUtils.sol";

contract NFTBackedTokenTest is Test {
    event Deposit(uint256[] tokenIds, address indexed to);
    event Redeem(uint256[] tokenIds, address indexed to);
    event Swap(uint256[] tokensIn, uint256[] tokensOut, address indexed to);
    event UpgradesDisabled();
    event AdminPowerBurned();
    event AdminSet(address indexed newAdmin);

    error OwnableUnauthorizedAccount(address account);
    error EnforcedPause();
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    IERC721 constant NOUNS_TOKEN = IERC721(0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03);
    address constant NOUNDERS = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    address constant TIMELOCK = 0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71;
    NFTBackedToken token;
    uint256[] nounIds;
    address admin = makeAddr("token admin");

    uint96 constant AMOUNT_PER_NFT_18_DECIMALS = 1_000_000 * 1e18;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 19538905);

        TokenDeployer tokenDeployer = new TokenDeployer();
        token = NFTBackedToken(
            tokenDeployer.deployToken({
                owner: TIMELOCK,
                name: "Nouns",
                symbol: "NOUNS",
                decimals: 18,
                erc721Token: address(NOUNS_TOKEN),
                amountPerNFT: AMOUNT_PER_NFT_18_DECIMALS,
                admin: admin
            })
        );
    }

    function test_name() public view {
        assertEq(token.name(), "Nouns");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "NOUNS");
    }

    function test_deposit() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);

        vm.expectEmit(true, true, true, true);
        emit Deposit(nounIds, NOUNDERS);

        token.deposit(nounIds);

        assertEq(token.balanceOf(NOUNDERS), 2_000_000 * 1e18);
        assertEq(NOUNS_TOKEN.ownerOf(1050), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1060), address(token));
    }

    function test_deposit_whenPaused_reverts() public {
        vm.prank(admin);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);
        token.deposit(nounIds);
    }

    function test_redeem() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        token.deposit(nounIds);

        vm.expectEmit(true, true, true, true);
        emit Redeem(nounIds, NOUNDERS);

        token.redeem(nounIds);

        assertEq(token.balanceOf(NOUNDERS), 0);
        assertEq(NOUNS_TOKEN.ownerOf(1050), NOUNDERS);
        assertEq(NOUNS_TOKEN.ownerOf(1060), NOUNDERS);
    }

    function test_redeem_givenInsufficientERC20s_reverts() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        token.deposit(nounIds);

        token.transfer(makeAddr("some recipient"), 1);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20InsufficientBalance.selector, NOUNDERS, 2_000_000 * 1e18 - 1, 2_000_000 * 1e18)
        );
        token.redeem(nounIds);
    }

    function test_redeem_whenPaused_reverts() public {
        vm.stopPrank();
        vm.startPrank(admin);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);
        token.redeem(nounIds);
    }

    function test_swap() public {
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1030);
        NOUNS_TOKEN.approve(address(token), 1040);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        nounIds = [1050, 1060];
        token.deposit(nounIds);
        uint256[] memory tokensIn = new uint256[](2);
        tokensIn[0] = 1030;
        tokensIn[1] = 1040;

        vm.expectEmit(true, true, true, true);
        emit Swap(tokensIn, nounIds, NOUNDERS);

        token.swap(tokensIn, nounIds);

        assertEq(NOUNS_TOKEN.ownerOf(1030), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1040), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1050), NOUNDERS);
        assertEq(NOUNS_TOKEN.ownerOf(1060), NOUNDERS);
    }

    function test_swap_whenPaused_reverts() public {
        vm.stopPrank();
        vm.startPrank(admin);
        token.pause();

        uint256[] memory tokensIn = new uint256[](0);
        vm.expectRevert(EnforcedPause.selector);
        token.swap(tokensIn, nounIds);
    }

    function test_upgrade() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        token.deposit(nounIds);
        vm.stopPrank();

        address newImpl = address(new NewContract());
        vm.prank(TIMELOCK);
        token.upgradeToAndCall(newImpl, bytes(""));

        NewContract token2 = NewContract(address(token));
        assertEq(token2.getVotes(NOUNDERS), 0);

        vm.prank(NOUNDERS);
        token2.delegate(NOUNDERS);
        assertEq(token2.getVotes(NOUNDERS), 2_000_000 * 1e18);
    }

    function test_upgradeToAndCall_givenDisabledUpgrades_reverts() public {
        vm.expectEmit(true, true, true, true);
        emit UpgradesDisabled();

        vm.prank(TIMELOCK);
        token.disableUpgrades();

        address newImpl = address(new NewContract());
        vm.prank(TIMELOCK);
        vm.expectRevert("upgrades disabled");
        token.upgradeToAndCall(newImpl, bytes(""));
    }

    function test_disableUpgrades_givenSenderNotOwner_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        token.disableUpgrades();
    }

    function test_redeemableNFTsBalance() public {
        address holder = makeAddr("holder");
        assertEq(token.redeemableNFTsBalance(holder), 0);

        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1030);
        NOUNS_TOKEN.approve(address(token), 1040);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        nounIds = [1030, 1040, 1050, 1060];
        token.deposit(nounIds);

        token.transfer(holder, 2_000_000 * 1e18);
        assertEq(token.redeemableNFTsBalance(holder), 2);

        token.transfer(holder, 999_999 * 1e18); // balance is now 2.999M, still rounding down to 2
        assertEq(token.redeemableNFTsBalance(holder), 2);

        token.transfer(holder, 1 * 1e18);
        assertEq(token.redeemableNFTsBalance(holder), 3);
    }

    function test_burnAdminPower_worksForAdmin() public {
        vm.expectEmit(true, true, true, true);
        emit AdminPowerBurned();

        vm.startPrank(admin);
        token.burnAdminPower();
        assertEq(token.admin(), address(0));
    }

    function test_burnAdminPower_worksForOwner() public {
        vm.expectEmit(true, true, true, true);
        emit AdminPowerBurned();

        vm.startPrank(TIMELOCK);
        token.burnAdminPower();
        assertEq(token.admin(), address(0));
    }

    function test_burnAdminPower_givenSenderNotAdminNorOwner_reverts() public {
        vm.startPrank(makeAddr("not admin nor owner"));
        vm.expectRevert("must be admin or owner");
        token.burnAdminPower();
    }

    function test_pause_worksForAdmin() public {
        vm.startPrank(admin);
        token.pause();
        assert(token.paused());
    }

    function test_pause_givenSenderNotAdmin_reverts() public {
        vm.startPrank(makeAddr("not admin"));
        vm.expectRevert("must be admin");
        token.pause();
    }

    function test_unpause_worksForAdmin() public {
        vm.startPrank(admin);
        token.pause();
        assert(token.paused());

        token.unpause();
        assert(!token.paused());
    }

    function test_unpause_worksForOwner() public {
        vm.startPrank(admin);
        token.pause();
        assert(token.paused());

        vm.stopPrank();
        vm.startPrank(TIMELOCK);
        token.unpause();
        assert(!token.paused());
    }

    function test_unpause_givenSenderNotAdminNorOwner_reverts() public {
        vm.startPrank(makeAddr("not admin nor owner"));
        vm.expectRevert("must be admin or owner");
        token.unpause();
    }

    function test_permit_works() public {
        SigUtils sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        (address owner, uint256 ownerPK) = makeAddrAndKey("owner");
        address spender = makeAddr("spender");
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 42 * 1e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPK, digest);

        token.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(token.allowance(owner, spender), 42 * 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function test_setAdmin_worksForOwner() public {
        vm.expectEmit(true, true, true, true);
        emit AdminSet(makeAddr("new admin"));

        vm.startPrank(TIMELOCK);
        token.setAdmin(makeAddr("new admin"));
        assertEq(token.admin(), makeAddr("new admin"));
    }

    function test_setAdmin_worksForAdmin() public {
        vm.expectEmit(true, true, true, true);
        emit AdminSet(makeAddr("new admin"));

        vm.startPrank(admin);
        token.setAdmin(makeAddr("new admin"));
        assertEq(token.admin(), makeAddr("new admin"));
    }

    function test_setAdmin_revertsForNonAdminNorOwner() public {
        vm.startPrank(makeAddr("not admin nor owner"));
        vm.expectRevert("must be admin or owner");
        token.setAdmin(makeAddr("new admin"));
    }
}

contract NewContract is NFTBackedToken, ERC20VotesUpgradeable {
    function nonces(address owner)
        public
        view
        virtual
        override(NoncesUpgradeable, ERC20PermitUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function decimals() public view virtual override(ERC20Upgradeable, NFTBackedToken) returns (uint8) {
        return super.decimals();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }
}
