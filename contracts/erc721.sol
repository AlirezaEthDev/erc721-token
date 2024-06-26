// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Interfaces
import "../interface/IERC721TokenReceiver.sol";
import "../interface/IERC165.sol";
import "../interface/IERC721.sol";
import "../interface/IERC721Metadata.sol";
import "../interface/IERC721Enumerable.sol";

// Contract
contract ERC721 is IERC165, IERC721, IERC721TokenReceiver, IERC721Metadata, ERC721Enumerable {
    //State variables
    address public collectionOwner;
    bytes public collectionName;
    bytes public collectionSymbol;
    address private recipientContractAddress;
    uint public totalSupplyCounter;
    uint public lastNftIndexOfCollection;

    //Events
    event CollectionCreate(address ownerOfCollection, bytes nameOfCollection, bytes symbolOfCollection);
    event CollectionRename(bytes previousName, bytes currentName, bytes previousSymbol, bytes currentSymbol);

    //Mappings
    mapping(address => uint256) private nftCountOfOwner;
    mapping(address => mapping(uint => uint256)) private nftListOfOwner;
    mapping(address => mapping(uint256 => uint)) private nftIndexOfOwner;
    mapping(address => uint) private lastNftIndexOfOwner;
    mapping(uint256 => address) private nftOwner;
    mapping(uint256 => bytes) private uriOf;
    mapping(uint256 => address) private approvedOf;
    mapping(address => mapping(address => bool)) private approvedForAllNFTsOf;
    mapping(uint => uint256) private nftFromCollection;
    mapping(uint256 => uint) private nftIndexInCollection;

    //Modifiers
    modifier justTransfer(address _from, address _to, uint256 _tokenId) {
        require( nftOwner[_tokenId] != address(0x0) && (nftOwner[_tokenId] == tx.origin || approvedOf[_tokenId] == tx.origin || approvedForAllNFTsOf[_from][tx.origin]) && nftOwner[_tokenId] == _from && _to != address(0x0), "03");
        // 03: At least one of input data is not valid!
        // Transfer NFT:
        nftOwner[_tokenId] = _to;
        nftCountOfOwner[_from] --;
        nftCountOfOwner[_to] ++;
        uint nftIndex = nftIndexOfOwner[_from][_tokenId];
        uint lastNftIndex = lastNftIndexOfOwner[_to];
        nftListOfOwner[_from][nftIndex] = 0;
        nftListOfOwner[_to][lastNftIndex ++] = _tokenId;
        emit Transfer(_from, _to, _tokenId);
        emit Approval(msg.sender, address(0x0), _tokenId);
        _;
    }

    //Functions
    constructor(bytes memory nameOfCollection, bytes memory symbolOfCollection) {
        collectionOwner = msg.sender;
        collectionName = nameOfCollection;
        collectionSymbol = symbolOfCollection;
        emit CollectionCreate(collectionOwner, collectionName, collectionSymbol);
    }

    function supportsInterface(bytes4 interfaceID) external override pure returns (bool){
        bool ierc721TokenReceiverId = (interfaceID == this.onERC721Received.selector);
        bool ierc165Id = (interfaceID == this.supportsInterface.selector);
        bool ierc721Id = (interfaceID == bytes4(keccak256("balanceOf(address)")) ^
                            bytes4(keccak256("ownerOf(uint256)")) ^
                            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")) ^
                            bytes4(keccak256("safeTransferFrom(address,address,uint256)")) ^
                            bytes4(keccak256("transferFrom(address,address,uint256)")) ^
                            bytes4(keccak256("approve(address,uint256)")) ^
                            bytes4(keccak256("setApprovalForAll(address,bool)")) ^
                            bytes4(keccak256("getApproved(uint256)")) ^
                            bytes4(keccak256("isApprovedForAll(address,address)")));
        bool ierc721MetadataId = (interfaceID == this.name.selector ^ this.symbol.selector ^ this.tokenURI.selector);
        bool ierc721EnumerableId = (interfaceID == this.totalSupply.selector ^ this.tokenByIndex.selector ^ this.tokenOfOwnerByIndex.selector);
        return (ierc721TokenReceiverId || ierc165Id || ierc721Id || ierc721MetadataId || ierc721EnumerableId);
        
    }

    function name() external override view returns (string memory){
        return string(collectionName);
    }

    function symbol() external override view returns (string memory){
        return string(collectionSymbol);
    }

    function mint(address ownerAddress, uint256 tokenId, bytes calldata metadataURI) external returns (bool){
        require(ownerAddress != address(0x0), "09");
        // 09: Owner address is zero!
        require(collectionOwner == msg.sender, "07");
        // 07: Only the owner of collection can do this job!
        uint lastNftIndex = lastNftIndexOfOwner[ownerAddress];
        nftListOfOwner[ownerAddress][lastNftIndex ++] = tokenId;
        nftIndexOfOwner[ownerAddress][tokenId] = lastNftIndex;
        nftFromCollection[lastNftIndexOfCollection] = tokenId;
        nftIndexInCollection[tokenId] = lastNftIndexOfCollection;
        nftOwner[tokenId] = ownerAddress;
        uriOf[tokenId] = metadataURI;
        nftCountOfOwner[ownerAddress] ++;
        lastNftIndexOfOwner[ownerAddress] ++;
        totalSupplyCounter ++;
        lastNftIndexOfCollection ++;
        uint codeSize;
        emit Transfer(address(0x0), ownerAddress, tokenId);
        assembly{
            codeSize := extcodesize(ownerAddress)
        }
        if(codeSize > 0){
            recipientContractAddress = ownerAddress;
            bytes4 functionSelector = this.onERC721Received(address(0x0), address(0x0), tokenId, "");
            require(functionSelector == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")), "04");
            // 04: The recipient contract couldn't handle the NFT receipt!
        }
        return true;
    }

    function burn(uint256 tokenId) external returns (bool){
        uint nftIndex = nftIndexOfOwner[msg.sender][tokenId];
        nftListOfOwner[msg.sender][nftIndex] = 0;
        nftOwner[tokenId] = address(0x0);
        uriOf[tokenId] = "";
        approvedOf[tokenId] = address(0x0);
        nftCountOfOwner[msg.sender] --;
        nftIndexInCollection[tokenId] = lastNftIndexOfCollection;
        nftFromCollection[lastNftIndexOfCollection] = 0;
        totalSupplyCounter --;
        emit Transfer(msg.sender, address(0x0), tokenId);
        return true;
    }

    function totalSupply() external override view returns (uint256){
        return totalSupplyCounter;
    }

    function tokenURI(uint256 _tokenId) external override view returns (string memory){
        return string(uriOf[_tokenId]);
    }

    function tokenByIndex(uint256 _index) external override view returns (uint256){
        require(_index <= lastNftIndexOfCollection, "06");
        // 06: The NFT index is invalid!
        return nftFromCollection[_index];
    }

    function balanceOf(address _owner) external override view returns (uint256){
        require(_owner != address(0x0), "01");
        // 01: Zero address is not valid!
        return nftCountOfOwner[_owner];
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external override view returns (uint256){
        require(_index <= nftCountOfOwner[_owner], "06");
        return nftListOfOwner[_owner][_index];
    }

    function ownerOf(uint256 _tokenId) external override view returns (address){
        require(nftOwner[_tokenId] != address(0x0), "02");
        // 02: The token is invalid!
        return (nftOwner[_tokenId]);
    }

    function collectionRename(bytes calldata newName, bytes calldata newSymbol) external {
        require(collectionOwner == msg.sender, "08");
        // 08: Only collection owner can rename it!
        emit CollectionRename(collectionName, newName, collectionSymbol, newSymbol);
        collectionName = newName;
        collectionSymbol = newSymbol;
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external override justTransfer(_from, _to, _tokenId) payable{    
        // Ensure if the recipient is a contract it handles the NFT receipt:
        uint codeSize;
        address operator = msg.sender;
        assembly{
            codeSize := extcodesize(_to)
        }
        if(codeSize > 0){
            recipientContractAddress = _to;
            bytes4 functionSelector = this.onERC721Received(operator, _from, _tokenId, data);
            require(functionSelector == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")), "04");
            // 04: The recipient contract couldn't handle the NFT receipt!
        }
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external override payable{
        this.safeTransferFrom(_from, _to, _tokenId, "");
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external override justTransfer(_from, _to, _tokenId) payable{}

    function approve(address _approved, uint256 _tokenId) external override payable{
        require(nftOwner[_tokenId] == msg.sender, "05");
        // 05: The account is not authorized!;
        approvedOf[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external override{
        approvedForAllNFTsOf[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) external override view returns (address){
        return approvedOf[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external override view returns (bool){
        return approvedForAllNFTsOf[_owner][_operator];
    }

    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external override returns(bytes4){
        IERC721TokenReceiver recipientContract = IERC721TokenReceiver(recipientContractAddress);
        return recipientContract.onERC721Received(_operator, _from, _tokenId, _data);
    }
}