// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./utils/Console.sol";


contract Temp is Console{
    string public name = "hello world";
    int[] global_arr;

    bytes32 a;
    constructor() {
        a = "helloworld";
    }

    function nameLength() public view returns (uint256){
        return bytes(name).length;
    }

    function modify() public {
        bytes(name)[0] = "H";
    }

    function modify_local() public view returns (string memory) {
        string memory local_string = name;
        bytes(local_string)[0] = "H";
        return local_string;
    }

    function arr_push() public {
        global_arr.push(123456);
        global_arr.push(111111);
        global_arr.push(-123456);
        for (uint i = 0; i < global_arr.length; i++) {
            log("arr_push", global_arr[i]);
        }

        global_arr.pop();
        for (uint i = 0; i < global_arr.length; i++) {
            log("arr_pop", global_arr[i]);
        }
    }

}
