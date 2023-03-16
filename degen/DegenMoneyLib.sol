// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library DegenMoneyLib {
    //****************
    // PARAMS
    //****************
    uint256 constant private _taskCreateMinFee = 10 * 10**18;
    uint256 constant private _groupCreateMinFee = 1 * 10**18;
    uint256 constant private _a = 3;        // 门票金额给队长的比例（%）
    uint256 constant private _b = 50;       // 门票金额投入奖池的比例（%）
    uint256 constant private _c = 10;       // 队长的最终奖池收益比例（%）
    uint256 constant private _p = 10;       // MonopolyPenalty比例（%）

    uint256 constant private _alpha = 2;
    uint256 constant private _beta = 10;               // beta = _beta / _denominator
    uint256 constant private _gamma = 0.01 * 10**18;    // absolute init ticket price threshold
    uint256 constant private _denominator = 100;

    function taskCreateMinFee() public pure returns (uint256 money) {
        return _taskCreateMinFee;
    }

    function groupCreateMinFee() public pure returns (uint256 money) {
        return _groupCreateMinFee;
    }

    function ticketPrice(uint256 ith, uint256 totalRewardPool, bool isMonopolyPenalty) public pure returns (uint256 price) {
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

        if (isMonopolyPenalty){
            uint256 extraFee = 0;
            (flag, extraFee) = SafeMath.tryMul(totalRewardPool, _p);
            require(flag, "Number overflow occurs when (flag, extraFee) = SafeMath.tryMul(totalRewardPool, _p)");
            (flag, extraFee) = SafeMath.tryDiv(extraFee, _denominator);
            require(flag, "Number overflow occurs when (flag, extraFee) = SafeMath.tryDiv(extraFee, _denominator)");
            (flag, tp) = SafeMath.tryAdd(tp, extraFee);
            require(flag, "Number overflow occurs when (flag, tp) = SafeMath.tryAdd(tp, extraFee)");
        }

        return tp;
    }

    function ticketIncome2RewardPool(uint256 ticketIncome) public pure returns (uint256 money) {
        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(ticketIncome, _b);
        require(flag, "[ticketIncome2RewardPool] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2RewardPool] overflow.");
        return m;
    }

    function ticketIncome2GroupLeader(uint256 ticketIncome) public pure returns (uint256 money) {
        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(ticketIncome, _a);
        require(flag, "[ticketIncome2GroupLeader] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2GroupLeader] overflow.");
        return m;
    }

    function ticketIncome2GroupMember(uint256 ticketIncome, uint256 memNum) public pure returns (uint256 money) {
        uint256 c = _denominator - _a - _b;

        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(ticketIncome, c);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, memNum);
        require(flag, "[ticketIncome2GroupMember] overflow.");

        return m;
    }

}

