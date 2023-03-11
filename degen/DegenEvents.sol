// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract DegenEvents {
    // fired whenever a task is created
    event onCreateNewTask
    (
        uint256 indexed taskId,
        address indexed ownerAddress,
        string indexed ownerName,
        uint256 amountPaid,
        uint256 createTimeStamp,
        uint256 taskStartStamp,
        uint256 taskEndStamp
    );
    
    // fired whenever a group is created
    event onCreateNewGroup
    (
        uint256 indexed affiliateTaskID,
        uint256 indexed groupId,
        address ownerAddress,
        string ownerName,
        uint256 amountPaid,
        uint256 createTimeStamp
    );

    // fired whenever a member join a group
    event onJoinGroup
    (
        uint256 indexed affiliateTaskID,
        uint256 indexed groupId,
        address playerAddress,
        string playerName,
        uint256 amountPaid,
        uint256 joinTimeStamp
    );

    // show current task status
    event currentTaskStatus
    (
        uint256 indexed taskId,
        address indexed ownerAddress,
        string indexed ownerName,
        uint256 ownerAmountPaid,
        uint256 taskStartStamp,
        uint256 taskEndStamp,
        uint256 totalRewardPool,
        uint256 totalGroupNumber,
        uint256 totalPeopleNumber
    );

    // show current group status
    event currentGroupStatus
    (
        uint256 indexed affiliateTaskID,
        uint256 indexed groupId,
        string ownerAddress,
        bytes32 ownerName,
        uint256 ownerAmountPaid,    // maybe init group creation fee or the price of leader NFT
        uint256 totalPeopleNumber
    );
}
