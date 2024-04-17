// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { TokenDeployer } from "../src/TokenDeployer.sol";

contract TokenDeployerTest is Test {
    TokenDeployer tokenDeployer = new TokenDeployer();

    function test_deployToken_givenWrongPredictedAddress_reverts() public {
        vm.expectRevert("token address does not match predicted address");
        tokenDeployer.deployToken({
            owner: makeAddr("owner"),
            name: "Nouns",
            symbol: "NOUNS",
            decimals: 18,
            erc721Token: makeAddr("erc721Token"),
            amountPerNFT: 1_000_000 * 1e18,
            admin: makeAddr("admin"),
            nonce: 0,
            predictedTokenAddress: address(0x123)
        });
    }

    function test_deployToken_givenGoodPredictedAddress_works() public {
        address predictedAddress = tokenDeployer.predictTokenAddress({
            msgSender: address(this),
            owner: makeAddr("owner"),
            name: "Nouns",
            symbol: "NOUNS",
            decimals: 18,
            erc721Token: makeAddr("erc721Token"),
            amountPerNFT: 1_000_000 * 1e18,
            admin: makeAddr("admin"),
            nonce: 0
        });

        tokenDeployer.deployToken({
            owner: makeAddr("owner"),
            name: "Nouns",
            symbol: "NOUNS",
            decimals: 18,
            erc721Token: makeAddr("erc721Token"),
            amountPerNFT: 1_000_000 * 1e18,
            admin: makeAddr("admin"),
            nonce: 0,
            predictedTokenAddress: predictedAddress
        });
    }
}
