// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library DegenTicketPrice {
    uint256 constant private _alpha = 2;
    uint256 constant private _beta = 10;               // beta = _beta / _denominator
    uint256 constant private _gamma = 0.01 * 10**18;    // absolute init ticket price threshold
    uint256 constant private _denominator = 100;

    function ticketPrice(uint256 ith) public pure returns (uint256 price) {
        require(_alpha <= 5, "To avoid overflow, alpha <= 5 only");

        bool flag = true;
        uint256 tp = 1;
        
        for (uint i=0; i < _alpha; i++) {
            (flag, tp) = SafeMath.tryMul(tp, ith);
            require(flag, "Number overflow occurs when calculate ticket price in i**_alpha.");
        }

        (flag, tp) = SafeMath.tryMul(tp, _beta);
        require(flag, "Number overflow occurs when calculate ticket price in _beta*i**_alpha.");

        (flag, tp) = SafeMath.tryDiv(tp, _denominator);
        require(flag, "Number overflow occurs when calculate ticket price in _beta/_denominator*i**_alpha.");

        (flag, tp) = SafeMath.tryMul(tp, 10**18);
        require(flag, "Number overflow occurs when calculate ticket price in (_beta/_denominator*i**_alpha)*10**18.");

        (flag, tp) = SafeMath.tryAdd(tp, _gamma);
        require(flag, "Number overflow occurs when calculate ticket price in _beta/_denominator*i**_alpha + gamma.");

        return tp;
    }
}

