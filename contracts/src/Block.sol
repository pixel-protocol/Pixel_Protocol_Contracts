// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pixel.sol";
import "./IBlock.sol";

contract Block is IBlock, ERC721, ERC721Enumerable, Ownable {
    uint256 private constant ID_LIMIT = 9999;

    Pixel private immutable _pixelContract;
    
    mapping(uint256 =>uint256[]) private _pixelIds;

    constructor(address pixelContract_) ERC721("Block","BLOCK"){
        _pixelContract = Pixel(pixelContract_);
    }

    function mint(uint256 id_, uint24[] memory colors_) external payable{
        require(!_exists(id_), "Block: Block already exists!");
        require(id_ <= ID_LIMIT, "Block: Block ID is over the ID limit");
        require(msg.value >= costPerPixel(id_) * 100, "Block: Insufficient ETH balance");
        require(colors_.length == 100, "Block: Invalid length of colors array");

        uint256 row = id_ / 100;
        uint256 col = id_ % 100;

        delete _pixelIds[id_];

        for(uint256 j=0;j<10;j++){
            for(uint256 k=0;k<10;k++){
                _pixelIds[id_].push(row * 10 * 1000 + col * 10 + j + k * 1000);
            }
        }

        uint256[] memory selectedPixelIds = _pixelIds[id_];

        _safeMint(msg.sender, id_);
        _pixelContract.mint(colors_, selectedPixelIds, msg.sender);

        emit Mint(msg.sender,id_, _pixelIds[id_], colors_);
        
    }

    function getXY(uint256 id_) public pure returns(uint256,uint256) { 
        return (id_ % 100, id_ / 100);
    }

    function getId(uint256 x, uint256 y) public pure returns(uint256) {
        return y * 100 + x;
    }
    
    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }

    function costPerPixel(uint256 id_) public pure returns(uint256){
        uint256[3] memory costs = [uint256(100 * 1e14), uint256(125 * 1e14), uint256(150 * 1e14)];
        return costs[tier(id_)];       
    }

    function tier(uint256 id_) public pure returns(uint256) {
        /* 
        3 Tiers:
        Platinum: 40 <= X < 60 && 40 <= Y < 60
        Gold:  20 <= X < 80 && 20 <= Y < 80
        Silver: remaining
        Platinum = 2; Gold = 1; Silver = 0;
        */

        (uint256 X, uint256 Y) = getXY(id_);

        if((X >= 40 && X < 60) && (Y>=40 && Y < 60)) {
            return 2;
        } 
        else if ((X >= 20 && X < 80) && (Y >= 20 && Y < 80)){
            return 1;
        }
        else {
            return 0;
        }
    }

    function getPixelIds(uint256 id_) external view returns(uint256[] memory){
        require(_exists(id_), "Block: Block is not yet minted");
        return _pixelIds[id_];

    }

    function getPixelOwners(uint256 id_) external view returns(address[] memory) {
        require(_exists(id_), "Block: Block is not yet minted");
        address[] memory owners = new address[](100);

        uint256[] memory selectedPixelIds = _pixelIds[id_];

        for(uint256 i=0;i<selectedPixelIds.length;i++){
            owners[i] = _pixelContract.pixelOwner(selectedPixelIds[i]);
        }
        return owners;

    }

    function getPixelColors(uint256 id_) external view returns(uint24[] memory) {
        require(_exists(id_), "Block: Block is not yet minted");
        uint24[] memory colors = new uint24[](100);

        uint256[] memory selectedPixelIds = _pixelIds[id_];

        for(uint256 i=0;i<selectedPixelIds.length;i++){
            colors[i] = _pixelContract.color(selectedPixelIds[i]);
        }
        return colors;
    }

    function withdraw() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override(ERC721Enumerable,ERC721) {
        // Add your custom logic for _beforeTokenTransfer function here
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable,ERC721) returns (bool) {
        // Add your custom logic for supportsInterface function here
        return super.supportsInterface(interfaceId);
    }
}
