// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { NFTBackedToken } from "./NFTBackedToken.sol";
import { LibClone } from "./libs/LibClone.sol";

contract TokenDeployer {
    address public immutable tokenImpl;

    constructor() {
        tokenImpl = address(new NFTBackedToken());
    }

    function deployToken(
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT
    ) public returns (address) {
        NFTBackedToken token = NFTBackedToken(LibClone.deployERC1967(address(tokenImpl)));
        token.initialize(owner, name, symbol, decimals, erc721Token, amountPerNFT);

        return address(token);
    }
}
