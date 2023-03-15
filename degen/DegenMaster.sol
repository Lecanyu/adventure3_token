// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DegenEvents.sol";
import "./NFT/GroupNFT.sol";
import "./DegenTicketPrice.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DegenMaster is DegenEvents {
    using Counters for Counters.Counter;

    //****************
    // PARAMS
    //****************
    uint256 constant private _taskCreateMinFee = 10 * 10**18;
    uint256 constant private _groupCreateMinFee = 1 * 10**18;
    uint256 constant private _a = 3;        // 队长的队伍门票分红比例（%）
    uint256 constant private _b = 50;       // 门票金额投入奖池的比例（%）
    uint256 constant private _c = 10;       // 队长的最终奖池收益比例（%）
    uint256 constant private _denominator = 100;


    //****************
    // PLAYER DATA 
    //****************
    mapping (address => string) public _pID2Name;
    mapping (address => uint256) public _pID2Reward;


    //****************
    // TASK DATA 
    //****************
    Counters.Counter private _taskCounter;

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
        uint256 totalPeopleNumber;      // count the all people involved in this task
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
        uint256 totalPeopleNumber;  // not count the group leader
    }

    mapping (uint256 => address) public _groupId2OwnerAddr;
    mapping (uint256 => GroupDetails) public _groupId2Details;
    mapping (uint256 => address[]) public _groupId2MemberAddrs;    // group id => member addr list
    mapping (uint256 => address) public _groupId2NFTAddr;           // group id => NFT addr
    address[] public _NFTAddrs;                                     // NFT Addrs

    constructor() {}

    //****************
    // utils
    //****************
    function getCurrentJoinGroupPrice(uint256 groupId) 
        public
        view
        returns (uint256 price)
    {
        // get current group member number
        uint256 grpMemNum = _groupId2MemberAddrs[groupId].length;

        // isPayEnoughForEnterGroup
        uint256 ticketPrice = DegenTicketPrice.ticketPrice(grpMemNum + 1);
        return ticketPrice;
    }


    // NFT trading func
    function nftTransferModifyStatus(address from, address to, uint256 tokenId) 
        isNFTContract
        public
    {

    }


    
    //****************
    // modifiers
    //****************
    modifier isHuman() {
        /**
        * @dev prevents contracts from interacting with fomo3d 
        */
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

    modifier isNFTContract() {
        bool allow = false;
        for(uint256 i=0; i<_NFTAddrs.length; i++){
            if(msg.sender == _NFTAddrs[i]){
                allow = true;
                break;
            }
        }
        require(allow, "only internal NFT contract");
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

    // todo: implement task ends


    //****************
    // group function
    //****************
    function createGroup(string memory groupName, string memory ownerName, uint256 affiliateTaskID) 
        isHuman
        isPayEnoughForGroupCreate
        public payable  
    {
        // TODO: judge if the task exist

        // group id
        uint256 groupId = _taskId2GroupIds[affiliateTaskID].length + 1;

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

        // modify task data
        _taskId2Details[affiliateTaskID].totalGroupNumber += 1;
        _taskId2Details[affiliateTaskID].totalPeopleNumber += 1;
        _taskId2GroupIds[affiliateTaskID].push(groupId);

        // money enter reward pool
        _taskId2Details[affiliateTaskID].totalRewardPool += msg.value;

        // leader creates group NFT contract
        string memory nftName = string.concat("taskId_", Strings.toString(affiliateTaskID), "_grpId_", Strings.toString(groupId));
        GroupNFT groupNFT = new GroupNFT(nftName, nftName, address(this));
        uint256 tokenId = groupNFT.safeMint(msg.sender);

        _groupId2NFTAddr[groupId] = address(groupNFT);
        _NFTAddrs.push(address(groupNFT));

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

    function joinGroup(uint256 groupId, uint256 affiliateTaskID, string memory playerName) 
        isHuman
        public payable  
    {
        // TODO: judge if the group exist

        // isPayEnoughForEnterGroup
        uint256 ticketPrice = getCurrentJoinGroupPrice(groupId);
        require(msg.value >= ticketPrice, string.concat("joinGroupFee should be large than ", Strings.toString(ticketPrice)));
        
        // player data
        _pID2Name[msg.sender] = playerName;
        
        // modify group and task data
        _taskId2Details[affiliateTaskID].totalPeopleNumber += 1;
        _groupId2MemberAddrs[groupId].push(msg.sender);
        _groupId2Details[groupId].totalPeopleNumber += 1;      

        // money enter the reward pool
        bool flag = false;
        uint256 rewardPoolMoney = 0;
        (flag, rewardPoolMoney) = SafeMath.tryMul(msg.value, _b);
        require(flag, "[joinGroup] (flag, rewardPoolMoney) = SafeMath.tryMul(msg.value, _b).");
        (flag, rewardPoolMoney) = SafeMath.tryDiv(rewardPoolMoney, _denominator);
        require(flag, "[joinGroup] (flag, rewardPoolMoney) = SafeMath.tryDiv(rewardPoolMoney, _denominator).");

        _taskId2Details[affiliateTaskID].totalRewardPool += rewardPoolMoney;

        // money distributed to group leader 
        uint256 grpLdReward = 0;
        (flag, grpLdReward) = SafeMath.tryMul(msg.value, _a);
        require(flag, "[joinGroup] (flag, grpLdReward) = SafeMath.tryMul(msg.value, _a).");
        (flag, grpLdReward) = SafeMath.tryDiv(grpLdReward, _denominator);
        require(flag, "[joinGroup] (flag, grpLdReward) = SafeMath.tryDiv(grpLdReward, _denominator).");

        _pID2Reward[_groupId2Details[groupId].ownerAddress] += grpLdReward;

        // money distributed to group members
        uint256 grpMemReward = 0;
        (flag, grpMemReward) = SafeMath.trySub(msg.value, rewardPoolMoney);
        require(flag, "[joinGroup] (flag, grpMemReward) = SafeMath.trySub(msg.value, rewardPoolMoney).");
        (flag, grpMemReward) = SafeMath.trySub(grpMemReward, grpLdReward);
        require(flag, "[joinGroup] (flag, grpMemReward) = SafeMath.trySub(grpMemReward, grpLdReward).");

        uint256 memNum = _groupId2MemberAddrs[groupId].length;
        uint256 eachReward = 0;
        (flag, eachReward) = SafeMath.tryDiv(grpMemReward, memNum);
        require(flag, "[joinGroup] (flag, eachReward) = SafeMath.tryDiv(grpMemReward, memNum).");

        address[] memory memAddrs = _groupId2MemberAddrs[groupId];
        for(uint idx=0; idx<memNum; idx++){
            _pID2Reward[memAddrs[idx]] += eachReward;
        }
        
        // mint a NFT for group member
        GroupNFT groupNFT = GroupNFT(_groupId2NFTAddr[groupId]);
        uint256 tokenId = groupNFT.safeMint(msg.sender);

        emit onJoinGroup
            (
                affiliateTaskID,
                groupId,
                msg.sender,
                playerName,
                msg.value,
                block.timestamp
            );
    }

}
