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
    address constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    address constant NOUNDERS = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
    address constant TIMELOCK = 0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71;
    NFTBackedToken token;
    uint256[] nounIds;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 19538905);

        TokenDeployer tokenDeployer = new TokenDeployer();
        token = NFTBackedToken(
            tokenDeployer.deployToken({
                owner: TIMELOCK,
                name: "Nouns",
                symbol: "NOUNS",
                decimals: 18,
                erc721Token: NOUNS_TOKEN,
                amountPerNFT: 1_000_000
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
        IERC721(NOUNS_TOKEN).approve(address(token), 1050);
        IERC721(NOUNS_TOKEN).approve(address(token), 1060);
        token.deposit(nounIds, NOUNDERS);

        assertEq(token.balanceOf(NOUNDERS), 2_000_000 * 1e18);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1050), address(token));
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1060), address(token));
    }

    function test_redeem() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        IERC721(NOUNS_TOKEN).approve(address(token), 1050);
        IERC721(NOUNS_TOKEN).approve(address(token), 1060);
        token.deposit(nounIds, NOUNDERS);

        token.redeem(nounIds, address(0x123));
        assertEq(token.balanceOf(NOUNDERS), 0);
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1050), address(0x123));
        assertEq(IERC721(NOUNS_TOKEN).ownerOf(1060), address(0x123));
    }

    function test_upgrade() public {
        nounIds = [1060, 1050];
        vm.startPrank(NOUNDERS);
        IERC721(NOUNS_TOKEN).approve(address(token), 1050);
        IERC721(NOUNS_TOKEN).approve(address(token), 1060);
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
