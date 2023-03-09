// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;


contract Temp {
    bytes32 a;
    constructor() 
    {
        a = "helloworld";
    }

    function modify() public {
        bytes1 t = a[0];
        a[0] = "H";
    }

}
