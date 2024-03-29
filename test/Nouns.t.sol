// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Nouns } from "../src/Nouns.sol";
import { IERC721 } from '../src/libs/IERC721.sol';
import { LibClone } from '../src/libs/LibClone.sol';
import { ERC20VotesUpgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import { ERC20PermitUpgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import { ERC20Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import { NoncesUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol';

contract NounsTest is Test {

    address constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    address constant NOUNDERS = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    address constant TIMELOCK = 0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71;
    Nouns nouns;
    uint256[] nounIds;

    function setUp() public {
        vm.createSelectFork(vm.envString('RPC_MAINNET'), 19538905);

        address nounsImpl = address(new Nouns(NOUNS_TOKEN));
        nouns = Nouns(LibClone.deployERC1967(address(nounsImpl)));
        nouns.initialize(TIMELOCK);
    }

    function test_name() public view {
        assertEq(nouns.name(), 'Nouns');
    }

    function test_symbol() public view {
        assertEq(nouns.symbol(), 'NOUNS');
    }

    function test_mint() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1050);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1060);
        nouns.mint(nounIds, NOUNDERS);

        assertEq(nouns.balanceOf(NOUNDERS), 2_000_000 * 1e18);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1050), address(nouns));
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1060), address(nouns));
    }

    function test_redeem() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1050);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1060);
        nouns.mint(nounIds, NOUNDERS);

        nouns.redeem(nounIds, address(0x123));
        assertEq(nouns.balanceOf(NOUNDERS), 0);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1050), address(0x123));
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1060), address(0x123));
    }

    function test_upgrade() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1050);
        IERC721(NOUNS_TOKEN).approve(address(nouns), 1060);
        nouns.mint(nounIds, NOUNDERS);
        vm.stopPrank();

        address newImpl = address(new NewContract(NOUNS_TOKEN));
        vm.prank(TIMELOCK);
        nouns.upgradeToAndCall(newImpl, bytes(''));

        NewContract nouns2 = NewContract(address(nouns));
        assertEq(nouns2.getVotes(NOUNDERS), 0);

        vm.prank(NOUNDERS);
        nouns2.delegate(NOUNDERS);
        assertEq(nouns2.getVotes(NOUNDERS), 2_000_000 * 1e18);
    }
}

contract NewContract is Nouns, ERC20VotesUpgradeable {
    constructor(address nounsToken_) Nouns(nounsToken_) {}

    function nonces(address owner) public view virtual override(NoncesUpgradeable, ERC20PermitUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function decimals() public view virtual override(ERC20Upgradeable, Nouns) returns (uint8) {
        return super.decimals();
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }
}