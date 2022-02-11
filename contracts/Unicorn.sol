// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Unicorn is ERC721 {

    uint256 private counter;

    constructor() ERC721("Unicorn", "UNIC") {
        counter = 0;
    }

    function mint() external {
        _mint(msg.sender, counter);
        counter++;
    }
}