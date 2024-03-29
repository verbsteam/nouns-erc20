// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from './libs/ERC20.sol';
import { IERC721 } from './libs/IERC721.sol';

contract Nouns is ERC20 {

    uint256 public constant MULTIPLIER = 1_000_000 * 1e18;

    IERC721 public immutable nounsToken;

    constructor(address nounsToken_) {
        nounsToken = IERC721(nounsToken_);
    }

    /// @dev Returns the name of the token.
    function name() public pure virtual override returns (string memory) {
        return "Nouns";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure virtual override returns (string memory) {
        return "NOUNS";
    }

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    
    function mint(uint256[] calldata nounIds, address to) public {
        for (uint256 i; i < nounIds.length; ++i) {
            nounsToken.transferFrom(msg.sender, address(this), nounIds[i]);
        }
        _mint(to, MULTIPLIER * nounIds.length);
    }

    function redeem(uint256[] calldata nounIds, address to) public {
        for (uint256 i; i < nounIds.length; ++i) {
            nounsToken.transferFrom(address(this), to, nounIds[i]);
        }
        _burn(to, MULTIPLIER * nounIds.length);
    }
}
