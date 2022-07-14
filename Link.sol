//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract Link is ERC20 {

    constructor() ERC20("Chainlink", "LINK") {

        _mint(msg.sender, 1000000000000000000);
    }

    // function _approve(address owner, uint amount) public {
    //     ERC20.approve(owner, amount);
    // }
}
