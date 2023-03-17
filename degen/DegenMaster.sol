// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DegenEvents.sol";
import "./NFT/GroupNFT.sol";
import "./DegenMoneyLib.sol";
import "../utils/StringUtils.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DegenMaster is DegenEvents {
    using Counters for Counters.Counter;

    address private _degenManager;

    //****************
    // NFT
    //****************
    GroupNFT private _groupNFT;
    mapping (uint256 => uint256) private _tokenId2TaskId;
    mapping (uint256 => uint256) private _tokenId2GroupId;
    mapping (uint256 => uint256) private _tokenId2Reward;
    mapping (uint256 => address) private _tokenId2PlayerAddr;


    //****************
    // PLAYER DATA 
    //****************
    mapping (address => string) private _pID2Name;
    mapping (address => uint256) private _pID2Reward;    // 玩家账户总奖励，累积值，当任务结算时更新该状态


    //****************
    // TASK DATA 
    //****************
    Counters.Counter private _taskCounter;

    struct TaskDetail{
        string taskName;
        uint256 taskId;
        address ownerAddress;
        string ownerName;
        uint256 amountPaid;
        uint256 createTimeStamp;
        uint256 taskStartStamp;
        uint256 taskEndStamp;

        uint256 totalRewardPool;
        uint256 totalGroupNum;
    }

    mapping (uint256 => TaskDetail) private _taskId2Detail;
    mapping (uint256 => uint256[]) private _taskId2TokenIds;

    //****************
    // GROUP DATA 
    //****************
    struct GroupDetail{
        string groupName;
        uint256 affiliateTaskID;
        uint256 groupId;
        address ownerAddress;
        string ownerName;
        uint256 createTimeStamp;
    }

    mapping (uint256 => mapping(uint256 => GroupDetail)) private _tidxgid2Detail;
    mapping (uint256 => mapping(uint256 => uint256[])) private _tidxgid2TokenIds;
    mapping (uint256 => mapping(uint256 => uint256)) private _tidxgid2LeaderTokenId;

    //****************
    // TEMP DATA 
    //****************
    mapping (address => bool) private _uniqueAddrs;


    constructor() {
        _groupNFT = new GroupNFT("DegenTaskNFT", "DTN", address(this));
        _degenManager = msg.sender;
    }

    //****************
    // task utils
    //****************
    function isTaskActive(uint256 taskId) public view returns(bool isAct) {
        if(block.timestamp > _taskId2Detail[taskId].taskEndStamp || 
            block.timestamp < _taskId2Detail[taskId].taskStartStamp){
            return false;
        }
        return true;
    }

    function getTaskRewardPool(uint256 taskId) public view returns (uint256 totalReward){
        return _taskId2Detail[taskId].totalRewardPool;
    }

    function getTaskPeopleNum(uint256 taskId) public view returns (uint256 num) {
        return _taskId2TokenIds[taskId].length;
    }

    function getTaskUniquePeopleNum(uint256 taskId) public returns (uint256 num) {
        if(_taskId2TokenIds[taskId].length <= 0){
            return 0;
        }
        
        uint256 upn = 0;
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            address addr = _tokenId2PlayerAddr[_taskId2TokenIds[taskId][i]];
            if(_uniqueAddrs[addr]){
                continue;
            }
            else{
                _uniqueAddrs[addr] = true;
                upn++;
            } 
        }

        // del temp mapping
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            address addr = _tokenId2PlayerAddr[_taskId2TokenIds[taskId][i]];
            delete _uniqueAddrs[addr];
        }
        return upn;
    }

    function getTaskGroupNum(uint256 taskId) public view returns (uint256 num) {
        return _taskId2Detail[taskId].totalGroupNum;
    }


    // return the biggest and second biggest group id
    function groupCompare(uint256 gid1PeopleNum, uint256 gid1Ts, uint256 gid2PeopleNum, uint256 gid2Ts) private pure returns (bool) {
        if(gid1PeopleNum > gid2PeopleNum){
            return false;
        }
        else if (gid1PeopleNum == gid2PeopleNum) {
            if(gid1Ts <= gid2Ts){
                return false;
            }
            else{
                return true;
            }
        }
        else{
            return true;
        }
    }
    function getTaskFirstSecondGroup(uint256 taskId) private view returns (int256 firstGrpId, int256 secondGrpId, uint256 firstGrpPeopleNum, uint256 secondGrpPeopleNum) {
        firstGrpId = -1;
        secondGrpId = -1;
        firstGrpPeopleNum = 0;
        secondGrpPeopleNum = 0;
        uint256 firstGidTs = 9999999999;
        uint256 secondGidTs = 9999999999;
        
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            uint256 gid = _tokenId2GroupId[_taskId2TokenIds[taskId][i]];
            uint256 num = getGroupPeopleNum(taskId, gid);
            uint256 ts = _tidxgid2Detail[taskId][gid].createTimeStamp;

            bool change = groupCompare(firstGrpPeopleNum, firstGidTs, num, ts);
            if(change){
                firstGrpId = int256(gid);
                firstGrpPeopleNum = num;
                firstGidTs = ts;
                continue;
            }
            else{
                change = groupCompare(secondGrpPeopleNum, secondGidTs, num, ts);
                if(change){
                    secondGrpId = int256(gid);
                    secondGrpPeopleNum = num;
                    secondGidTs = ts;
                }
            }
        }

        return (firstGrpId, secondGrpId, firstGrpPeopleNum, secondGrpPeopleNum);
    }

    //****************
    // group utils
    //****************
    function isGroupActive(uint256 taskId, uint256 groupId) public view returns (bool){
        if(isTaskActive(taskId) == false){
            return false;
        }

        if(block.timestamp < _tidxgid2Detail[taskId][groupId].createTimeStamp){
            return false;
        }
        return true;
    }

    function getGroupPeopleNum(uint256 taskId, uint256 groupId) public view returns (uint256 num){
        return _tidxgid2TokenIds[taskId][groupId].length;
    }

    function getCurrentJoinGroupPrice(uint256 taskId, uint256 groupId) private view returns (uint256 price){
        // get current group member number, rule out group leader
        uint256 grpMemNum = getGroupPeopleNum(taskId, groupId) - 1;

        // get current group status
        int256 firstGrpId;
        int256 SecondGrpId;
        uint256 firstGrpPeopleNum;
        uint256 secondGrpPeopleNum;
        (firstGrpId, SecondGrpId, firstGrpPeopleNum, secondGrpPeopleNum) = getTaskFirstSecondGroup(taskId);

        uint256 ticketPrice = DegenMoneyLib.ticketPrice(grpMemNum + 1, _taskId2Detail[taskId].totalRewardPool, firstGrpId, SecondGrpId, firstGrpPeopleNum, secondGrpPeopleNum);
        return ticketPrice;
    }

    //****************
    // NFT utils
    //****************
    function nftTransferModifyStatus(address from, address to, uint256 tokenId) 
        isNFTContract
        external
    {
        _tokenId2PlayerAddr[tokenId] = to;

        _tidxgid2Detail[_tokenId2TaskId[tokenId]][_tokenId2GroupId[tokenId]].ownerAddress = to;
        _tidxgid2Detail[_tokenId2TaskId[tokenId]][_tokenId2GroupId[tokenId]].ownerName = _pID2Name[to];

        emit onNFTTraded(
            _tokenId2TaskId[tokenId],
            _tokenId2GroupId[tokenId],
            from,
            to,
            tokenId,
            block.timestamp
        );
    }
    
    //****************
    // player utils
    //****************


    
    //****************
    // modifiers
    //****************
    modifier onlyManager() {
        require(msg.sender == _degenManager, "The caller must be manager.");
        _;
    }

    modifier onlyTaskOwner(uint256 taskId) {
        require(msg.sender == _taskId2Detail[taskId].ownerAddress, "The caller must be task owner.");
        _;
    }

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
        require(msg.value >= DegenMoneyLib.taskCreateMinFee(), "isPayEnoughForTaskCreate failed");
        _;
    }

    modifier isPayEnoughForGroupCreate() {
        require(msg.value >= DegenMoneyLib.groupCreateMinFee(), "isPayEnoughForGroupCreate failed");
        _;
    }

    modifier isNFTContract() {
        require(msg.sender == address(_groupNFT), "only internal NFT contract");
        _;
    }

    //****************
    // player function
    //****************
    function registerPlayerName(string memory name) 
        isHuman 
        public
    {
        _pID2Name[msg.sender] = name;
    }


    //****************
    // task function
    //****************
    function createTask(string memory taskName, uint256 taskStartStamp, uint256 taskEndStamp) 
        isHuman
        isPayEnoughForTaskCreate
        public payable  
    {
        _taskCounter.increment();
        uint256 taskId = _taskCounter.current();
        
        // task data
        TaskDetail memory taskDet = TaskDetail({
            taskName: taskName,
            taskId: taskId,
            ownerAddress: msg.sender,
            ownerName: _pID2Name[msg.sender],
            amountPaid: msg.value,
            createTimeStamp: block.timestamp,
            taskStartStamp: taskStartStamp,
            taskEndStamp: taskEndStamp,

            totalRewardPool: msg.value,
            totalGroupNum: 0
        });
        _taskId2Detail[taskId] = taskDet;

        emit onCreateNewTask(
                taskDet.taskId,
                taskDet.ownerAddress,
                taskDet.ownerName,
                taskDet.amountPaid,
                taskDet.createTimeStamp,
                taskDet.taskStartStamp,
                taskDet.taskEndStamp
            );
    }

    function endTask(uint256 taskId)
        onlyManager
        public
    {
        // normal end

        // insufficent people refund
    }

    //****************
    // group function
    //****************
    function createGroup(string memory groupName, uint256 affiliateTaskID) 
        isHuman
        isPayEnoughForGroupCreate
        public payable  
    {
        // judge if the task exist
        require(isTaskActive(affiliateTaskID), "task must be active");

        // group id
        uint256 groupId = getTaskGroupNum(affiliateTaskID);

        // money enter reward pool
        _taskId2Detail[affiliateTaskID].totalRewardPool += msg.value;

        // mint leader NFT
        uint256 tokenId = _groupNFT.safeMint(msg.sender);
        _tokenId2TaskId[tokenId] = affiliateTaskID;
        _tokenId2GroupId[tokenId] = groupId;
        _tokenId2Reward[tokenId] = 0;
        _tokenId2PlayerAddr[tokenId] = msg.sender;

        // group data
        GroupDetail memory groupDet = GroupDetail({
            groupName: groupName,
            affiliateTaskID: affiliateTaskID,
            groupId: groupId,
            ownerAddress: msg.sender,
            ownerName: _pID2Name[msg.sender],
            createTimeStamp: block.timestamp
        });
        _tidxgid2Detail[affiliateTaskID][groupId] = groupDet;
        _tidxgid2TokenIds[affiliateTaskID][groupId].push(tokenId);
        _tidxgid2LeaderTokenId[affiliateTaskID][groupId] = tokenId;

        // task data
        _taskId2Detail[affiliateTaskID].totalGroupNum += 1;


        emit onCreateNewGroup
            (
                groupDet.affiliateTaskID,
                groupDet.groupId,
                groupDet.ownerAddress,
                groupDet.groupName,
                groupDet.ownerName,
                groupDet.createTimeStamp
            );
    }

    function joinGroup(uint256 groupId, uint256 affiliateTaskID) 
        isHuman
        public payable  
    {
        // judge if the group exist
        require(isGroupActive(affiliateTaskID, groupId), "group must be active");

        // isPayEnoughForEnterGroup
        uint256 ticketPrice = getCurrentJoinGroupPrice(affiliateTaskID, groupId);
        require(msg.value >= ticketPrice, string.concat("joinGroupFee should be large than ", Strings.toString(ticketPrice)));  

        // mint a NFT for group member
        uint256 tokenId = _groupNFT.safeMint(msg.sender);
        _tokenId2TaskId[tokenId] = affiliateTaskID;
        _tokenId2GroupId[tokenId] = groupId;
        _tokenId2Reward[tokenId] = 0;
        _tokenId2PlayerAddr[tokenId] = msg.sender;

        // money enter the reward pool
        _taskId2Detail[affiliateTaskID].totalRewardPool += DegenMoneyLib.ticketIncome2RewardPool(msg.value);

        // money distributed to group leader 
        uint256 gldTokenId = _tidxgid2LeaderTokenId[affiliateTaskID][groupId];
        _tokenId2Reward[gldTokenId] = DegenMoneyLib.ticketIncome2GroupLeader(msg.value);

        // money distributed to group members
        uint256 memNum = _tidxgid2TokenIds[affiliateTaskID][groupId].length - 1;    // ruleout leader
        for(uint i=0; i<memNum; i++){
            uint256 tid = _tidxgid2TokenIds[affiliateTaskID][groupId][i];
            if(tid != gldTokenId){
                _tokenId2Reward[tid] += DegenMoneyLib.ticketIncome2GroupMember(msg.value, memNum);
            }
        }

        emit onJoinGroup
            (
                affiliateTaskID,
                groupId,
                msg.sender,
                _pID2Name[msg.sender],
                msg.value,
                block.timestamp
            );
    }

}
