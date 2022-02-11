// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProfitToken is ERC20 {

    address private admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "ProfitToken::not admin");
        _;
    }

    constructor(address _admin) ERC20("ProfitToken", "PROT") {
        admin = _admin; // In our case, the admin should be the racing contract.
    }

    function mint(address _to, uint256 _amount) external onlyAdmin {
        _mint(_to, _amount);
    }
}