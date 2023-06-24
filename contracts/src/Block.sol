// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pixel.sol";

contract Block is ERC721, ERC721Enumerable, Ownable {
    error Block__AlreadyMinted(uint256 id);
    error Block__InvalidId(uint256 num);
    error Block__InsufficientETH(uint256 expected, uint256 actual);
    error Block__InvalidColorsLength();

    uint256 private constant ID_LIMIT = 9999;

    Pixel private immutable _pixelContract;
    
    mapping(uint256 =>uint256[]) private _pixelIds;

    event Mint(address indexed owner, uint256 indexed id, uint256[] pixelIds, uint24[] pixelColors);
    
    constructor(address pixelContract_) ERC721("Block","BLOCK"){
        _pixelContract = Pixel(pixelContract_);
    }

    function mint(uint256 id_, uint24[] memory colors_) external payable{
        if(id_ > ID_LIMIT) revert Block__InvalidId(id_);
        if(_exists(id_)) revert Block__AlreadyMinted(id_);
        if(msg.value < costPerPixel(id_) * 100) revert Block__InsufficientETH(costPerPixel(id_) * 100,msg.value);
        if(colors_.length!=100) revert Block__InvalidColorsLength();

        uint256 x = id_ % 100;
        uint256 y = id_ / 100;

        delete _pixelIds[id_];

        for(uint256 j=0;j<10;){
            for(uint256 k=0;k<10;){
                _pixelIds[id_].push(x * 10 + y * 10 * 1000 + k + j*1000);
                unchecked {
                    k++;
                }
            }
            unchecked {
                j++;
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
        /// @notice mint price of pixel, determined by tier
        /// Tiers:
        /// A: 0.001 MATIC
        /// B: 0.0015 MATIC
        /// C: 0.002 MATIC

        uint256[3] memory costs = [uint256(100 * 1e13), uint256(150 * 1e13), uint256(200 * 1e13)];
        return costs[tier(id_)];       
    }

    function tier(uint256 id_) public pure returns(uint256) {
        /// @notice 3 Tiers:
        /// A: 40 <= X < 60 && 40 <= Y < 60
        /// B: 20 <= X < 80 && 20 <= Y < 80
        /// C: remaining
        /// A = 2; B = 1; C = 0;

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
        return _pixelIds[id_];

    }

    function getPixelOwners(uint256 id_) external view returns(address[] memory) {
        address[] memory owners = new address[](100);
        if (_exists(id_)){
            uint256[] memory selectedPixelIds = _pixelIds[id_];

            uint256 numPixels = selectedPixelIds.length;

            for(uint256 i=0;i<numPixels;){
                owners[i] = _pixelContract.ownerOf(selectedPixelIds[i]);
                unchecked{
                    ++i;
                }
            }
        }
        
        return owners;

    }

    function getPixelColors(uint256 id_) external view returns(uint24[] memory) {
        uint24[] memory colors = new uint24[](100);

        if(_exists(id_)) {
            uint256[] memory selectedPixelIds = _pixelIds[id_];
            uint256 numPixels = selectedPixelIds.length;

            for(uint256 i=0;i<numPixels;){
                colors[i] = _pixelContract.color(selectedPixelIds[i]);
                unchecked {
                    ++i;
                }
            }
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
