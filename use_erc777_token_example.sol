// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";

// 收到token后即销毁
contract ReceiveAndBurn is IERC777Sender, IERC777Recipient {
    event TokensReceived(address indexed operator, address indexed from, address indexed to, uint256 amount, string log_text);
    event TokensToSend(address indexed operator, address indexed from, address indexed to, uint256 amount, string log_text);
    
    mapping(address => uint256) public givers;
    address private _owner;
    IERC777 private _token;

    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    constructor(IERC777 token) {
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), _TOKENS_SENDER_INTERFACE_HASH, address(this));
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), _TOKENS_RECIPIENT_INTERFACE_HASH, address(this));

        _owner = msg.sender;
        _token = token;
    }

    // 查询某个地址送出的token
    function showGive(address g) public view virtual returns (uint256) {
        return givers[g];
    }

    // 收款时被回调
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        givers[from] += amount;
        emit TokensReceived(operator, from, to, amount, "token received");
    }

    // 转出时被回调
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        emit TokensToSend(operator, from, to, amount, "token to send");
    }

    // 管理员销毁收到的token
    function burn() external {
        require(msg.sender == _owner, "no permision");
        uint256 balance = _token.balanceOf(address(this));
        _token.burn(balance, "");
    }
}
