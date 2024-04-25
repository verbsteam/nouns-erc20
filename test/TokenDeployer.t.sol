// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { TokenDeployer } from "../src/TokenDeployer.sol";

contract TokenDeployerTest is Test {
    event TokenDeployed(
        address indexed msgSender,
        address indexed owner,
        string name,
        string symbol,
        uint8 decimals,
        address erc721Token,
        uint96 amountPerNFT,
        address admin,
        uint8 nonce,
        address tokenAddress
    );

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

        vm.expectEmit(true, true, true, true);
        emit TokenDeployed(
            address(this),
            makeAddr("owner"),
            "Nouns",
            "NOUNS",
            18,
            makeAddr("erc721Token"),
            1_000_000 * 1e18,
            makeAddr("admin"),
            0,
            predictedAddress
        );

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
