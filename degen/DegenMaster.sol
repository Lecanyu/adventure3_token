// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DegenEvents.sol";
import "./DegenMoneyLib.sol";
import "./DegenNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DegenMaster is DegenEvents {
    using Counters for Counters.Counter;

    address private _degenManager;

    //****************
    // use specific token 
    //**************** 
    address constant private _rewardTokenAddr = 0xDA0bab807633f07f013f94DD0E6A4F96F8742B53; // need to set the token contract addr
    IERC20 private _rewardToken;

    //****************
    // NFT
    //****************
    uint256 constant private _maxNFTMintNum = 3;
    DegenNFT private _degenNFT;
    mapping (uint256 => uint256) private _tokenId2TaskId;
    mapping (uint256 => uint256) private _tokenId2GroupId;
    mapping (uint256 => uint256) private _tokenId2Reward;
    mapping (uint256 => address) private _tokenId2PlayerAddr;


    //****************
    // PLAYER DATA 
    //****************
    mapping (address => string) private _playerAddr2Name;
    mapping (address => uint256[]) private _playerAddr2TokenIds;


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
        bool hasEnd;
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

    // TEMP DATA for calculation
    mapping (address => bool) private _uniqueAddrs;
    mapping (uint256 => uint256) private _taskId2NFTNum;


    //****************
    // modifiers
    //****************
    modifier onlyManager() {
        require(msg.sender == _degenManager, "The caller must be manager.");
        _;
    }

    modifier onlyManagerOrTaskOwner(uint256 taskId) {
        require(msg.sender == _taskId2Detail[taskId].ownerAddress || msg.sender == _degenManager, "The caller must be task owner or manager.");
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

    modifier isNFTContract() {
        require(msg.sender == address(_degenNFT), "only internal NFT contract");
        _;
    }

    modifier isExceedMaxNftNum(uint256 taskId) {
        bool exceed = false;
        for(uint256 i=0; i<_playerAddr2TokenIds[msg.sender].length; i++){
            uint256 tid = _tokenId2TaskId[_playerAddr2TokenIds[msg.sender][i]];
            if(tid == taskId){
                _taskId2NFTNum[taskId] += 1;
                if(_taskId2NFTNum[taskId] >= _maxNFTMintNum){
                    exceed = true;
                    break;
                }
            }
        }
        // restore variable
        delete _taskId2NFTNum[taskId];

        require(exceed == false, string.concat("Hold NFT number is large than ", Strings.toString(_maxNFTMintNum), " in taskId ", Strings.toString(taskId)));
        _;
    }

    constructor() {
        _degenNFT = new DegenNFT("DegenTaskNFT", "DTN", address(this));
        _rewardToken = IERC20(_rewardTokenAddr);
        _degenManager = msg.sender;

        emit onConstruction(address(_degenNFT));
    }

    

    //****************
    // NFT utils
    //****************
    function getTokenId2Reward(uint256 tokenId) public view returns(uint256 reward) {
        return _tokenId2Reward[tokenId];
    }

    //****************
    // player utils
    //****************
    function playerAddr2TaskIdsGroupIdsTokenIds(address playerAddr) public view returns (uint256[] memory, uint256[] memory, uint256[] memory){
        uint256[] memory tids = new uint256[](_playerAddr2TokenIds[playerAddr].length);
        uint256[] memory gids = new uint256[](_playerAddr2TokenIds[playerAddr].length);
        for(uint256 i=0; i<_playerAddr2TokenIds[playerAddr].length; i++){
            tids[i] = _tokenId2TaskId[_playerAddr2TokenIds[playerAddr][i]];
            gids[i] = _tokenId2GroupId[_playerAddr2TokenIds[playerAddr][i]];
        }
        return (tids, gids, _playerAddr2TokenIds[playerAddr]);
    }

    //****************
    // task utils
    //****************
    function isTaskActive(uint256 taskId) public view returns(bool isAct) {
        if(_taskId2Detail[taskId].hasEnd){
            return false;
        }

        if(block.timestamp > _taskId2Detail[taskId].taskEndStamp || 
            block.timestamp < _taskId2Detail[taskId].taskStartStamp){
            return false;
        }
        return true;
    }

    function getTaskCreateFee() public pure returns (uint256){
        return DegenMoneyLib.taskCreateMinFee();
    }

    function getTaskName(uint256 taskId) public view returns (string memory){
        return _taskId2Detail[taskId].taskName;
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

    // get all group ids in a specific task (// return value may repeat)
    function getTaskAllGroupIds(uint256 taskId) public view returns (uint256[] memory) {
        uint256[] memory gids = new uint256[](_taskId2TokenIds[taskId].length);
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            uint256 gid = _tokenId2GroupId[_taskId2TokenIds[taskId][i]];
            gids[i] = gid;
        }
        return gids;
    }

    function getTaskNewestGroupId(uint256 taskId) public view returns (uint256) {
        uint256 newestGroupId = 0;
        uint256 newestTs = 9999999999;
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            uint256 gid = _tokenId2GroupId[_taskId2TokenIds[taskId][i]];
            uint256 ts = _tidxgid2Detail[taskId][gid].createTimeStamp;
            if(ts < newestTs){
                ts = newestTs;
                newestGroupId = gid;
            }
        }
        return newestGroupId;
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
    function getTaskFirstSecondGroup(uint256 taskId) public view returns (int256 firstGrpId, int256 secondGrpId, uint256 firstGrpPeopleNum, uint256 secondGrpPeopleNum) {
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

            if(int256(gid) == firstGrpId || int256(gid) == secondGrpId){
                continue;
            }

            bool change = groupCompare(firstGrpPeopleNum, firstGidTs, num, ts);
            if(change){
                secondGrpId = firstGrpId;
                secondGrpPeopleNum = firstGrpPeopleNum;
                secondGidTs = firstGidTs;

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

        if(_tidxgid2Detail[taskId][groupId].createTimeStamp == 0){
            return false;
        }
        return true;
    }

    function getGroupName(uint256 taskId, uint256 groupId) public view returns (string memory){
        return _tidxgid2Detail[taskId][groupId].groupName;
    }

    function getGroupLeaderAddr(uint256 taskId, uint256 groupId) public view returns (address){
        return _tidxgid2Detail[taskId][groupId].ownerAddress;
    }

    function getGroupCreateTimeStamp(uint256 taskId, uint256 groupId) public view returns (uint256){
        return _tidxgid2Detail[taskId][groupId].createTimeStamp;
    }

    // the total people in group, including the leader
    function getGroupPeopleNum(uint256 taskId, uint256 groupId) public view returns (uint256 num){
        return _tidxgid2TokenIds[taskId][groupId].length;
    }

    function getGroupCreateFee() public pure returns (uint256){
        return DegenMoneyLib.groupCreateMinFee();
    }

    function getGroupCreateNFTMintFee() public pure returns (uint256) {
        return DegenMoneyLib.groupCreateNFTMintFee();
    }

    function getCurrentJoinGroupPrice(uint256 taskId, uint256 groupId) public view returns (uint256){
        require(isGroupActive(taskId, groupId), "group must be active");

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

    function getCurrentJoinGroupNFTMintFee(uint256 ticketPrice) public pure returns (uint256){
        uint256 mintFee = DegenMoneyLib.joinGroupNFTMintFee(ticketPrice);
        return mintFee;
    }

    // instant earn
    function getCurrentJoinGroupIncome(uint256 taskId, uint256 groupId) public view returns (uint256){
        require(isGroupActive(taskId, groupId), "group must be active");
        // get current group member number, rule out group leader
        uint256 grpMemNum = getGroupPeopleNum(taskId, groupId) - 1;

        uint256 currentIncome = DegenMoneyLib.ticketIncome2GroupMember(
            getCurrentJoinGroupPrice(taskId, groupId), 
            grpMemNum + 1
        );
        return currentIncome;
    }

    // estimate next player earn
    function getNextJoinGroupIncome(uint256 taskId, uint256 groupId) public view returns (uint256){
        require(isGroupActive(taskId, groupId), "group must be active");

        // get current group member number, rule out group leader
        uint256 grpMemNum = getGroupPeopleNum(taskId, groupId) - 1;

        // get current group status
        int256 firstGrpId;
        int256 SecondGrpId;
        uint256 firstGrpPeopleNum;
        uint256 secondGrpPeopleNum;
        (firstGrpId, SecondGrpId, firstGrpPeopleNum, secondGrpPeopleNum) = getTaskFirstSecondGroup(taskId);

        uint256 nextTicketPrice = DegenMoneyLib.ticketPrice(grpMemNum + 2, _taskId2Detail[taskId].totalRewardPool, firstGrpId, SecondGrpId, firstGrpPeopleNum, secondGrpPeopleNum);
        uint256 nextIncome = DegenMoneyLib.ticketIncome2GroupMember(nextTicketPrice, grpMemNum + 2);
        return nextIncome;
    }


    //****************
    // NFT contract call degen utils
    //****************
    function nftTransferModifyStatus(address from, address to, uint256 tokenId) 
        isNFTContract
        external
    {
        _tokenId2PlayerAddr[tokenId] = to;

        for(uint256 i=0; i<_playerAddr2TokenIds[from].length; i++){
            if(_playerAddr2TokenIds[from][i] == tokenId){   // delete the tokenid 
                _playerAddr2TokenIds[from][i] = _playerAddr2TokenIds[from][_playerAddr2TokenIds[from].length - 1];
                _playerAddr2TokenIds[from].pop();
            }
        }
        // add the tokenid
        _playerAddr2TokenIds[to].push(tokenId);
        

        // group leader change
        if(_tidxgid2LeaderTokenId[_tokenId2TaskId[tokenId]][_tokenId2GroupId[tokenId]] == tokenId){
            _tidxgid2Detail[_tokenId2TaskId[tokenId]][_tokenId2GroupId[tokenId]].ownerAddress = to;
            _tidxgid2Detail[_tokenId2TaskId[tokenId]][_tokenId2GroupId[tokenId]].ownerName = _playerAddr2Name[to];
        }
        
        emit onNFTTraded(
            _tokenId2TaskId[tokenId],
            _tokenId2GroupId[tokenId],
            from,
            to,
            tokenId,
            block.timestamp
        );
    }

    function payReward(uint256 tokenId, address player)
        isNFTContract
        external
    {
        _rewardToken.transfer(player, _tokenId2Reward[tokenId]);
        _tokenId2Reward[tokenId] = 0;

        for(uint256 i=0; i<_playerAddr2TokenIds[player].length; i++){
            if(_playerAddr2TokenIds[player][i] == tokenId){   // delete the tokenid 
                _playerAddr2TokenIds[player][i] = _playerAddr2TokenIds[player][_playerAddr2TokenIds[player].length - 1];
                _playerAddr2TokenIds[player].pop();
            }
        }
    }
    

    //****************
    // player function
    //****************
    // function registerPlayerName(string memory name) 
    //     isHuman 
    //     public
    // {
    //     _playerAddr2Name[msg.sender] = name;
    // }


    //****************
    // task function
    //****************
    function createTask(string memory taskName, uint256 taskStartStamp, uint256 taskEndStamp) 
        isHuman
        public  payable
        returns (uint256)
    {
        // isPayEnoughForTaskCreate
        require(_rewardToken.transferFrom(msg.sender, address(this), getTaskCreateFee()), string.concat("createTaskFee should be large than ", Strings.toString(getTaskCreateFee())));

        uint256 taskId = _taskCounter.current();
        _taskCounter.increment();
        
        // task data
        TaskDetail memory taskDet = TaskDetail({
            taskName: taskName,
            taskId: taskId,
            ownerAddress: msg.sender,
            ownerName: _playerAddr2Name[msg.sender],
            amountPaid: DegenMoneyLib.taskCreateMinFee(),
            createTimeStamp: block.timestamp,
            taskStartStamp: taskStartStamp,
            taskEndStamp: taskEndStamp,

            totalRewardPool: DegenMoneyLib.taskCreateMinFee(),
            totalGroupNum: 0,
            hasEnd: false
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
        
        return taskId;
    }

    function endTask(uint256 taskId)
        onlyManagerOrTaskOwner(taskId)
        public
    {
        // normal end
        // 1. reward pool to winner group
        int256 firstGrpId;
        (firstGrpId, , , ) = getTaskFirstSecondGroup(taskId);

        uint256 winnerGrpId = uint256(firstGrpId);
        uint256 totalReward = getTaskRewardPool(taskId);

        // reward pool distributed to group leader 
        uint256 gldTokenId = _tidxgid2LeaderTokenId[taskId][winnerGrpId];
        _tokenId2Reward[gldTokenId] += DegenMoneyLib.rewardPool2GroupLeader(totalReward);

        // reward pool distributed to group members
        uint256 memNum = getGroupPeopleNum(taskId, winnerGrpId) - 1;    
        for(uint i=0; i<_tidxgid2TokenIds[taskId][winnerGrpId].length; i++){
            uint256 tid = _tidxgid2TokenIds[taskId][winnerGrpId][i];
            if(tid != gldTokenId){      // ruleout leader
                _tokenId2Reward[tid] += DegenMoneyLib.rewardPool2GroupMember(totalReward, memNum);
            }
        }

        // reward pool distributed to ad3
        _rewardToken.transfer(_degenManager, DegenMoneyLib.rewardPool2AD3(totalReward));

        // set task reward to 0
        _taskId2Detail[taskId].totalRewardPool = 0;

        // set task end
        _taskId2Detail[taskId].hasEnd = true;

        // 2. set all NFTs burnable in this task
        for(uint256 i=0; i<_taskId2TokenIds[taskId].length; i++){
            _degenNFT.setBurnable(_taskId2TokenIds[taskId][i]);
        }
    }

    //****************
    // group function
    //****************
    function createGroup(string memory groupName, uint256 affiliateTaskID) 
        isHuman
        isExceedMaxNftNum(affiliateTaskID)
        public payable
        returns (uint256)
    {
        // judge if the task exist
        require(isTaskActive(affiliateTaskID), "task must be active");

        // isPayEnoughForGroupCreate
        require(_rewardToken.transferFrom(msg.sender, address(this), getGroupCreateFee()), string.concat("createGroupFee should be large than ", Strings.toString(getGroupCreateFee())));
        require(_rewardToken.transferFrom(msg.sender, _degenManager, getGroupCreateNFTMintFee()), string.concat("createGroupNFTMintFee should be large than ", Strings.toString(getGroupCreateNFTMintFee())));

        // group id
        uint256 groupId = getTaskGroupNum(affiliateTaskID);

        // mint leader NFT
        uint256 tokenId = _degenNFT.safeMint(msg.sender);
        _tokenId2TaskId[tokenId] = affiliateTaskID;
        _tokenId2GroupId[tokenId] = groupId;
        _tokenId2Reward[tokenId] = 0;
        _tokenId2PlayerAddr[tokenId] = msg.sender;

        // player data
        _playerAddr2TokenIds[msg.sender].push(tokenId);

        // group data
        GroupDetail memory groupDet = GroupDetail({
            groupName: groupName,
            affiliateTaskID: affiliateTaskID,
            groupId: groupId,
            ownerAddress: msg.sender,
            ownerName: _playerAddr2Name[msg.sender],
            createTimeStamp: block.timestamp
        });
        _tidxgid2Detail[affiliateTaskID][groupId] = groupDet;
        _tidxgid2TokenIds[affiliateTaskID][groupId].push(tokenId);
        _tidxgid2LeaderTokenId[affiliateTaskID][groupId] = tokenId;

        // task data
        _taskId2Detail[affiliateTaskID].totalGroupNum += 1;
        _taskId2Detail[affiliateTaskID].totalRewardPool += DegenMoneyLib.groupCreateMinFee();
        _taskId2TokenIds[affiliateTaskID].push(tokenId);

        emit onCreateNewGroup
            (
                groupDet.affiliateTaskID,
                groupDet.groupId,
                groupDet.ownerAddress,
                groupDet.groupName,
                groupDet.ownerName,
                groupDet.createTimeStamp
            );
        
        return groupId;
    }

    function joinGroup(uint256 groupId, uint256 affiliateTaskID) 
        isHuman
        isExceedMaxNftNum(affiliateTaskID)
        public payable  
        returns (uint256)
    {
        // judge if the group exist
        require(isGroupActive(affiliateTaskID, groupId), "group must be active");

        // isPayEnoughForEnterGroup
        uint256 ticketPrice = getCurrentJoinGroupPrice(affiliateTaskID, groupId);
        require(_rewardToken.transferFrom(msg.sender, address(this), ticketPrice), string.concat("joinGroupFee should be large than ", Strings.toString(ticketPrice)));
        require(_rewardToken.transferFrom(msg.sender, _degenManager, getCurrentJoinGroupNFTMintFee(ticketPrice)), string.concat("joinGroupNFTMintFee should be large than ", Strings.toString(getCurrentJoinGroupNFTMintFee(ticketPrice))));

        // mint a NFT for group member
        uint256 tokenId = _degenNFT.safeMint(msg.sender);
        _tokenId2TaskId[tokenId] = affiliateTaskID;
        _tokenId2GroupId[tokenId] = groupId;
        _tokenId2Reward[tokenId] = 0;
        _tokenId2PlayerAddr[tokenId] = msg.sender;

        // player data
        _playerAddr2TokenIds[msg.sender].push(tokenId);

        // task data
        _taskId2TokenIds[affiliateTaskID].push(tokenId);

        // group data
        _tidxgid2TokenIds[affiliateTaskID][groupId].push(tokenId);

        // money enter the reward pool
        _taskId2Detail[affiliateTaskID].totalRewardPool += DegenMoneyLib.ticketIncome2RewardPool(ticketPrice);

        // money distributed to group leader 
        uint256 gldTokenId = _tidxgid2LeaderTokenId[affiliateTaskID][groupId];
        _tokenId2Reward[gldTokenId] += DegenMoneyLib.ticketIncome2GroupLeader(ticketPrice);

        // money distributed to group members
        uint256 memNum = getGroupPeopleNum(affiliateTaskID, groupId) - 1;    
        for(uint i=0; i<_tidxgid2TokenIds[affiliateTaskID][groupId].length; i++){
            uint256 tid = _tidxgid2TokenIds[affiliateTaskID][groupId][i];
            if(tid != gldTokenId){      // ruleout leader
                _tokenId2Reward[tid] += DegenMoneyLib.ticketIncome2GroupMember(ticketPrice, memNum);
            }
        }

        emit onJoinGroup
            (
                affiliateTaskID,
                groupId,
                msg.sender,
                _playerAddr2Name[msg.sender],
                ticketPrice,
                block.timestamp
            );
        
        return groupId;
    }

}
