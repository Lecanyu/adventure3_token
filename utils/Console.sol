// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Console {
    event LogUint256(string, uint256);

    function log(string memory s, uint256 x) internal {
        emit LogUint256(s, x);
    }

    event LogInt(string, int256);

    function log(string memory s, int256 x) internal {
        emit LogInt(s, x);
    }

    event LogBytes(string, bytes);

    function log(string memory s, bytes memory x) internal {
        emit LogBytes(s, x);
    }

    event LogBytes32(string, bytes32);

    function log(string memory s, bytes32 x) internal {
        emit LogBytes32(s, x);
    }

    event LogAddress(string, address);

    function log(string memory s, address x) internal {
        emit LogAddress(s, x);
    }

    event LogBool(string, bool);

    function log(string memory s, bool x) internal {
        emit LogBool(s, x);
    }
}
