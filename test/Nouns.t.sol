// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Nouns } from "../src/Nouns.sol";
import { IERC721 } from '../src/libs/IERC721.sol';

contract NounsTest is Test {

    address constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    address public constant NOUNDERS = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    Nouns nouns;
    uint256[] nounIds;

    function setUp() public {
        vm.createSelectFork(vm.envString('RPC_MAINNET'), 19538905);

        nouns = new Nouns(NOUNS_TOKEN);
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

        nouns.redeem(nounIds, NOUNDERS);
        assertEq(nouns.balanceOf(NOUNDERS), 0);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1050), NOUNDERS);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1060), NOUNDERS);
    }
}