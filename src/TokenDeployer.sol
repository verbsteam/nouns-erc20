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
        address erc721Token,
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint88 unitsPerNFT
    ) public returns (address) {
        NFTBackedToken token = NFTBackedToken(LibClone.deployERC1967(address(tokenImpl)));
        token.initialize(erc721Token, owner, name, symbol, decimals, unitsPerNFT);

        return address(token);
    }
}
