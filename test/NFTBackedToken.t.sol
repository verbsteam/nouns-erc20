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
import { ERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

contract NFTBackedTokenTest is Test {
    error OwnableUnauthorizedAccount(address account);

    IERC721 constant NOUNS_TOKEN = IERC721(0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03);
    address constant NOUNDERS = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    address constant TIMELOCK = 0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71;
    NFTBackedToken token;
    uint256[] nounIds;
    address admin = makeAddr("token admin");

    uint88 constant AMOUNT_PER_NFT_18_DECIMALS = 1_000_000 * 1e18;

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
        token.deposit(nounIds, NOUNDERS);

        assertEq(token.balanceOf(NOUNDERS), 2_000_000 * 1e18);
        assertEq(NOUNS_TOKEN.ownerOf(1050), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1060), address(token));
    }

    function test_redeem() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        token.deposit(nounIds, NOUNDERS);

        token.redeem(nounIds, address(0x123));
        assertEq(token.balanceOf(NOUNDERS), 0);
        assertEq(NOUNS_TOKEN.ownerOf(1050), address(0x123));
        assertEq(NOUNS_TOKEN.ownerOf(1060), address(0x123));
    }

    function test_swap() public {
        address swapRecipient = makeAddr("swap recipient");

        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1030);
        NOUNS_TOKEN.approve(address(token), 1040);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        nounIds = [1050, 1060];
        token.deposit(nounIds, NOUNDERS);
        uint256[] memory tokensIn = new uint256[](2);
        tokensIn[0] = 1030;
        tokensIn[1] = 1040;

        token.swap(tokensIn, nounIds, swapRecipient);

        assertEq(NOUNS_TOKEN.ownerOf(1030), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1040), address(token));
        assertEq(NOUNS_TOKEN.ownerOf(1050), swapRecipient);
        assertEq(NOUNS_TOKEN.ownerOf(1060), swapRecipient);
    }

    function test_upgrade() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        token.deposit(nounIds, NOUNDERS);
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

    function test_balanceToBackingNFTCount() public {
        address holder = makeAddr("holder");
        assertEq(token.balanceToBackingNFTCount(holder), 0);

        vm.startPrank(NOUNDERS);
        NOUNS_TOKEN.approve(address(token), 1030);
        NOUNS_TOKEN.approve(address(token), 1040);
        NOUNS_TOKEN.approve(address(token), 1050);
        NOUNS_TOKEN.approve(address(token), 1060);
        nounIds = [1030, 1040, 1050, 1060];
        token.deposit(nounIds, NOUNDERS);

        token.transfer(holder, 2_000_000 * 1e18);
        assertEq(token.balanceToBackingNFTCount(holder), 2);

        token.transfer(holder, 999_999 * 1e18); // balance is now 2.999M, still rounding down to 2
        assertEq(token.balanceToBackingNFTCount(holder), 2);

        token.transfer(holder, 1 * 1e18);
        assertEq(token.balanceToBackingNFTCount(holder), 3);
    }

    function test_burnAdminPower_worksForAdmin() public {
        vm.startPrank(admin);
        token.burnAdminPower();
        assertEq(token.admin(), address(0));
    }

    function test_burnAdminPower_worksForOwner() public {
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

        changePrank(TIMELOCK);
        token.unpause();
        assert(!token.paused());
    }

    function test_unpause_givenSenderNotAdminNorOwner_reverts() public {
        vm.startPrank(makeAddr("not admin nor owner"));
        vm.expectRevert("must be admin or owner");
        token.unpause();
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

    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, NFTBackedToken)
        returns (uint8)
    {
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
