// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { NFTBackedToken } from "./NFTBackedToken.sol";
import { LibClone } from "./libs/LibClone.sol";

contract TokenDeployer {
    event TokenDeployed(
        address indexed msgSender,
        address indexed owner,
        string name,
        string symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT,
        address admin,
        uint8 nonce,
        address tokenAddress
    );

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
        uint88 amountPerNFT,
        address admin,
        uint8 nonce,
        address predictedTokenAddress
    ) external returns (address token) {
        token = deployToken(owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, nonce);
        require(token == predictedTokenAddress, "token address does not match predicted address");
    }

    function deployToken(
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT,
        address admin
    ) external returns (address) {
        return deployToken(owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, 0);
    }

    function deployToken(
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT,
        address admin,
        uint8 nonce
    ) public returns (address) {
        NFTBackedToken token = NFTBackedToken(
            LibClone.deployDeterministicERC1967(
                address(tokenImpl),
                salt(msg.sender, owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, nonce)
            )
        );
        token.initialize(owner, name, symbol, decimals, erc721Token, amountPerNFT, admin);

        emit TokenDeployed(
            msg.sender, owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, nonce, address(token)
        );

        return address(token);
    }

    function predictTokenAddress(
        address msgSender,
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT,
        address admin,
        uint8 nonce
    ) external view returns (address) {
        return LibClone.predictDeterministicAddress(
            LibClone.initCodeHashERC1967(tokenImpl),
            salt(msgSender, owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, nonce),
            address(this)
        );
    }

    function salt(
        address msgSender,
        address owner,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address erc721Token,
        uint88 amountPerNFT,
        address admin,
        uint8 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(msgSender, owner, name, symbol, decimals, erc721Token, amountPerNFT, admin, nonce)
        );
    }
}
