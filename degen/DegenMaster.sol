// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DegenEvents.sol";
import "./NFT/GroupNFT.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DegenMaster is DegenEvents {
    using Counters for Counters.Counter;

    //****************
    // PARAMS
    //****************
    uint256 constant private _taskCreateMinFee = 10 * 10**18;
    uint256 constant private _groupCreateMinFee = 0.1 * 10**18;

    //****************
    // PLAYER DATA 
    //****************
    mapping (address => string) public _pID2Name;


    //****************
    // TASK DATA 
    //****************
    Counters.Counter private _taskCounter;
    Counters.Counter private _groupCounter;

    struct TaskDetails{
        string taskName;
        uint256 taskId;
        address ownerAddress;
        string ownerName;
        uint256 amountPaid;
        uint256 createTimeStamp;
        uint256 taskStartStamp;
        uint256 taskEndStamp;

        uint256 totalRewardPool;
        uint256 totalGroupNumber;
        uint256 totalPeopleNumber;
    }

    mapping (uint256 => address) public _taskId2OwnerAddr;       // task id => task owner
    mapping (uint256 => TaskDetails) public _taskId2Details;
    mapping (uint256 => uint256[]) public _taskId2GroupIds;    // task id => group id list


    //****************
    // GROUP DATA 
    //****************
    struct GroupDetails{
        string groupName;
        uint256 affiliateTaskID;
        uint256 groupId;
        address ownerAddress;
        string ownerName;
        uint256 createTimeStamp;

        uint256 ownerAmountPaid;    // maybe init group creation fee or the price of leader NFT
        uint256 totalPeopleNumber;
    }

    mapping (uint256 => address) public _groupId2OwnerAddr;
    mapping (uint256 => GroupDetails) public _groupId2Details;
    mapping (uint256 => address[]) public _groupId2MemberIds;    // group id => member id list

    constructor() {}

    
    //****************
    // modifiers
    //****************
    /**
     * @dev prevents contracts from interacting with fomo3d 
     */
    modifier isHuman() {
        address addr = msg.sender;
        uint256 codeLength;
        
        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        _;
    }

    modifier isPayEnoughForTaskCreate() {
        require(msg.value >= _taskCreateMinFee, string.concat("taskCreateMinFee should be large than ", Strings.toString(_taskCreateMinFee)));
        _;
    }

    modifier isPayEnoughForGroupCreate() {
        require(msg.value >= _groupCreateMinFee, string.concat("groupCreateMinFee should be large than ", Strings.toString(_groupCreateMinFee)));
        _;
    }


    //****************
    // task function
    //****************
    function createTask(string memory taskName, string memory ownerName, uint256 taskStartStamp, uint256 taskEndStamp) 
        isHuman
        isPayEnoughForTaskCreate
        public payable  
    {
        _taskCounter.increment();
        uint256 taskId = _taskCounter.current();

        // player data
        _pID2Name[msg.sender] = ownerName;
        
        // task data
        TaskDetails memory taskDet = TaskDetails({
            taskName: taskName,
            taskId: taskId,
            ownerAddress: msg.sender,
            ownerName: ownerName,
            amountPaid: msg.value,
            createTimeStamp: block.timestamp,
            taskStartStamp: taskStartStamp,
            taskEndStamp: taskEndStamp,

            totalRewardPool: msg.value,
            totalGroupNumber: 0,
            totalPeopleNumber: 0
        });
        _taskId2Details[taskId] = taskDet;
        _taskId2OwnerAddr[taskId] = msg.sender;

        emit onCreateNewTask(
                taskId,
                taskDet.ownerAddress,
                ownerName,
                taskDet.amountPaid,
                taskDet.createTimeStamp,
                taskDet.taskStartStamp,
                taskDet.taskEndStamp
            );
    }

    //****************
    // group function
    //****************
    function createGroup(string memory groupName, string memory ownerName, uint256 affiliateTaskID) 
        isHuman
        isPayEnoughForGroupCreate
        public payable  
    {
        _groupCounter.increment();
        uint256 groupId = _groupCounter.current();

        // player data
        _pID2Name[msg.sender] = ownerName;
        
        // group data
        GroupDetails memory groupDet = GroupDetails({
            groupName: groupName,
            affiliateTaskID: affiliateTaskID,
            groupId: groupId,
            ownerAddress: msg.sender,
            ownerName: ownerName,
            createTimeStamp: block.timestamp,

            ownerAmountPaid: msg.value,
            totalPeopleNumber: 0
        });
        _groupId2Details[groupId] = groupDet;
        _groupId2OwnerAddr[groupId] = msg.sender;

        // create group leader NFT
        string memory taskName = _taskId2Details[affiliateTaskID].taskName;
        string memory nftName = string.concat(taskName, "_group_", Strings.toString(groupId));
        GroupNFT groupNFT = new GroupNFT(nftName, nftName);
        groupNFT.safeMint(msg.sender);

        emit onCreateNewGroup
            (
                groupDet.affiliateTaskID,
                groupDet.groupId,
                groupDet.ownerAddress,
                groupDet.ownerName,
                groupDet.ownerAmountPaid,
                groupDet.createTimeStamp
            );
    }

    // TODO: 
    // function joinGroup(uint256 groupId, uint256 affiliateTaskID) 
    //     isHuman
    //     public payable  
    // {
    //     _groupCounter.increment();
    //     uint256 groupId = _groupCounter.current();

    //     // player data
    //     _pID2Name[msg.sender] = ownerName;
        
    //     // group data
    //     GroupDetails memory groupDet = GroupDetails({
    //         groupName: groupName,
    //         affiliateTaskID: affiliateTaskID,
    //         groupId: groupId,
    //         ownerAddress: msg.sender,
    //         ownerName: ownerName,
    //         createTimeStamp: block.timestamp,

    //         ownerAmountPaid: msg.value,
    //         totalPeopleNumber: 0
    //     });
    //     _groupId2Details[groupId] = groupDet;
    //     _groupId2OwnerAddr[groupId] = msg.sender;
    // }

}
