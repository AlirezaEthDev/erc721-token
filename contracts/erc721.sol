// SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

// Interfaces
interface IERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) external returns(bytes4);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

// Contract
contract ERC721 is IERC165, IERC721, IERC721TokenReceiver {

    mapping(address => uint256) private nftCount;
    mapping(uint256 => address) private ownerOf;
    mapping(uint256 => address) private approvedOf;
    mapping(address => mapping(address => bool)) private approvedForAllNFTsOf

    modifier justTransfer(address _from, address _to, uint256 _tokenId) {
        require(ownerOf[_tokenId] != address(0x0) && (ownerOf[_tokenId] == msg.sender || approvedOf[_tokenId] == msg.sender || approvedForAllNFTsOf[_from][msg.sender]) && ownerOf[_tokenId] == _from && _to != address(0x0), "03");
        // 03: At least one of input data is not valid!
        // Transfer NFT:
        ownerOf[_tokenId] = _to;
        nftCount[_from] --;
        nftCount[_to] ++;
        _;
    }

    function balanceOf(address _owner) external view returns (uint256){
        require(_owner != address(0x0), "01");
        // 01: Zero address is not valid!
        return nftCount[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address){
        require(ownerOf[_tokenId] != address(0x0), "02");
        // 02: The token is invalid!
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external justTransfer(_from, _to, _tokenId) payable{    
        // Ensure if the recipient is a contract it handles the NFT receipt:
        uint codeSize;
        address operator = msg.sender;
        assembly{
            codeSize := extcodesize(_to)
        }
        if(codeSize > 0){
            IERC721TokenReceiver recipientContract = IERC721TokenReceiver(_to);
            bytes4 functionSelector = recipientContract.onERC721Received(operator, _from, _tokenId, data);
            require(functionSelector == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")), "04");
            // 04: The recipient contract couldn't handle the NFT receipt!
        }
        emit Transfer(_from, _to, _tokenId);
        emit Approval(msg.sender, address(0x0), _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable{
        this.safeTransferFrom(_from, _to, _tokenId, "");
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external justTransfer(_from, _to, _tokenId) payable{
        emit Transfer(_from, _to, _tokenId);
        emit Approval(msg.sender, address(0x0), _tokenId);
    }

    function approve(address _approved, uint256 _tokenId) external payable{
        require(ownerOf(_tokenId) == msg.sender, "05");
        // 05: The account is not authorized!;
        approvedOf[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external{
        approvedForAllNFTsOf[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) external view returns (address){
        return approvedOf[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool){
        return approvedForAllNFTsOf[_owner][_operator];
    }
}