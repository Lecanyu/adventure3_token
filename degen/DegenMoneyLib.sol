// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library DegenMoneyLib {
    event LogUint256(string, uint256);

    uint256 constant private _decimal = 10**18;
    //****************
    // PARAMS
    //****************
    uint256 constant private _taskCreateMinFee = 0.01 * 10**18;
    uint256 constant private _groupCreateMinFee = 0.001 * 10**18;
    uint256 constant private _a = 30;        // 门票金额给队长的比例（%）
    uint256 constant private _b = 500;       // 门票金额投入奖池的比例（%）
    uint256 constant private _c = 100;       // 队长的最终奖池收益比例（%）
    uint256 constant private _p = 100;       // MonopolyPenalty比例（%）
    uint256 constant private _v = 10;       // 第一名队伍比第二名队伍人数多_v时，触发MonopolyPenalty

    uint256 constant private _alpha = 2;
    uint256 constant private _beta = 1;               // beta = _beta / _denominator
    uint256 constant private _gamma = 0.0001 * 10**18;    // absolute init ticket price threshold
    uint256 constant private _denominator = 1000;

    function taskCreateMinFee() public pure returns (uint256 money) {
        return _taskCreateMinFee;
    }

    function groupCreateMinFee() public pure returns (uint256 money) {
        return _groupCreateMinFee;
    }

    //****************
    // ticket function
    //****************
    function ticketPrice(
        uint256 ith, 
        uint256 totalRewardPool,
        int256 firstGrpId,
        int256 SecondGrpId,
        uint256 firstGrpPeopleNum,
        uint256 secondGrpPeopleNum
    ) 
    public pure returns (uint256 price) 
    {
        require(_alpha <= 5, "To avoid overflow, alpha <= 5 only");

        bool flag = true;
        uint256 tp = 1;
        
        for (uint i=0; i < _alpha; i++) {
            (flag, tp) = SafeMath.tryMul(tp, ith);
            require(flag, "Number overflow occurs when calculate ticket price in i**_alpha.");
        }

        (flag, tp) = SafeMath.tryMul(tp, _beta);
        require(flag, "Number overflow occurs when calculate ticket price in _beta*i**_alpha.");

        (flag, tp) = SafeMath.tryMul(tp, _decimal);
        require(flag, "Number overflow occurs when calculate ticket price in (_beta/_denominator*i**_alpha)*10**18.");

        (flag, tp) = SafeMath.tryDiv(tp, _denominator);
        require(flag, "Number overflow occurs when calculate ticket price in _beta/_denominator*i**_alpha.");
        
        (flag, tp) = SafeMath.tryAdd(tp, _gamma);
        require(flag, "Number overflow occurs when calculate ticket price in _beta/_denominator*i**_alpha + gamma.");


        // uint256 tp = _beta * ith ** _alpha * 10**18 / _denominator + _gamma;

        bool isMonopolyPenalty;
        if(firstGrpId >= 0 && SecondGrpId >= 0){
            if(firstGrpPeopleNum - secondGrpPeopleNum > _v){
                isMonopolyPenalty = true;
            }
            else {
                isMonopolyPenalty = false;
            }
        }
        else if (firstGrpId >= 0 && SecondGrpId < 0){
            if(firstGrpPeopleNum > _v) {
                isMonopolyPenalty = true;
            }
            else {
                isMonopolyPenalty = false;
            }
        }
        else{
            isMonopolyPenalty = false;
        }

        if (isMonopolyPenalty){
            uint256 extraFee = 0;
            (flag, extraFee) = SafeMath.tryMul(totalRewardPool, _p);
            require(flag, "Number overflow occurs when (flag, extraFee) = SafeMath.tryMul(totalRewardPool, _p)");
            (flag, extraFee) = SafeMath.tryDiv(extraFee, _denominator);
            require(flag, "Number overflow occurs when (flag, extraFee) = SafeMath.tryDiv(extraFee, _denominator)");
            (flag, tp) = SafeMath.tryAdd(tp, extraFee);
            require(flag, "Number overflow occurs when (flag, tp) = SafeMath.tryAdd(tp, extraFee)");

            // tp += totalRewardPool * _p / _denominator;
        }

        return tp;
    }

    function ticketIncome2RewardPool(uint256 ticketIncome) public pure returns (uint256 money) {
        // return ticketIncome * _b / _denominator;

        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(ticketIncome, _b);
        require(flag, "[ticketIncome2RewardPool] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2RewardPool] overflow.");
        return m;
    }

    function ticketIncome2GroupLeader(uint256 ticketIncome) public pure returns (uint256 money) {
        // return ticketIncome * _a / _denominator;

        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(ticketIncome, _a);
        require(flag, "[ticketIncome2GroupLeader] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2GroupLeader] overflow.");
        return m;
    }

    function ticketIncome2GroupMember(uint256 ticketIncome, uint256 memNum) public pure returns (uint256 money) {
        // return ticketIncome * (_denominator - _a - _b) / _denominator / memNum;

        bool flag = false;
        uint256 m = 0;
        uint256 c = 0;
        (flag, c) = SafeMath.trySub(_denominator, _a);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, c) = SafeMath.trySub(c, _b);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, m) = SafeMath.tryMul(ticketIncome, c);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[ticketIncome2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, memNum);
        require(flag, "[ticketIncome2GroupMember] overflow.");

        return m;
    }

    //****************
    // reward pool function
    //****************
    function rewardPool2GroupLeader(uint256 totalReward) public pure returns (uint256 money) {
        // return totalReward * _c / _denominator;

        bool flag = false;
        uint256 m = 0;
        (flag, m) = SafeMath.tryMul(totalReward, _c);
        require(flag, "[rewardPool2GroupLeader] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[rewardPool2GroupLeader] overflow.");

        return m;
    }

    function rewardPool2GroupMember(uint256 totalReward, uint256 memNum) public pure returns (uint256 money) {
        // return ticketIncome * (_denominator - _c) / _denominator / memNum;

        bool flag = false;
        uint256 m = 0;
        uint256 c = 0;
        (flag, c) = SafeMath.trySub(_denominator, _c);
        require(flag, "[rewardPool2GroupMember] overflow.");
        (flag, m) = SafeMath.tryMul(totalReward, c);
        require(flag, "[rewardPool2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, _denominator);
        require(flag, "[rewardPool2GroupMember] overflow.");
        (flag, m) = SafeMath.tryDiv(m, memNum);
        require(flag, "[rewardPool2GroupMember] overflow.");

        return m;
    }
}

