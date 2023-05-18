// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Block.sol";
import "./RentFactory.sol";
import "./IPixel.sol";

contract Pixel is IPixel, ERC1155, Ownable {
    uint256 private constant INVERSE_COLOR = 16777216;
    uint256 private constant ID_LIMIT = 999999;

    Block private _blockContract;
    bool private _blockContractAlreadySet;

    mapping(uint256 => address) private _pixelOwner;
    mapping(uint256 => uint24) private _color;
    mapping(uint256 => bool) private _exists;



    constructor() ERC1155(""){
    }

    function mint(uint24[] memory colors_, uint256[] memory ids_, address buyer_) external {
        require(msg.sender==address(_blockContract), "Only Block contract can mint!");
        uint256[] memory ones = new uint256[](ids_.length);
        for (uint256 i = 0; i < ids_.length; i++) {
            _exists[ids_[i]] = true;
            _color[ids_[i]] = colors_[i];
            _pixelOwner[ids_[i]] = buyer_;
            ones[i] = 1;
        }
        _mintBatch(buyer_, ids_, ones, "");
        emit ColorChange(buyer_, ids_, colors_);
    }

    function transform(uint24 color_, uint256 id_) external {
        require(_exists[id_], "Pixel: Pixel not minted");
        require(msg.sender==_pixelOwner[id_], "Pixel: Not the owner");
        _color[id_] = color_;
        emit ColorChange(msg.sender,_asSingletonArrayUINT256(id_), _asSingletonArrayUINT24(color_));
    }

    function transform(uint24[] memory colors_, uint256[] memory ids_) external {
        require(colors_.length == ids_.length, "Pixel: Array lengths mismatch");
        require(ids_.length<=100, "Pixel: Batch limit exceeded");

        for (uint256 i = 0; i < ids_.length; i++) {
            if(!_exists[ids_[i]]) {
                revert("Pixel: Pixel not minted");
            }
            
            if (msg.sender != _pixelOwner[ids_[i]]){
                revert("Pixel: Not the owner");
            }
        }        

        for (uint256 i = 0; i < ids_.length; i++) {
            _color[ids_[i]] = colors_[i];
        }

        emit ColorChange(msg.sender, ids_, colors_);
    }
    

    function getXY(uint256 id_) public pure returns(uint256,uint256) { 
        return (id_ % 1000, id_ / 1000);
    }

    function getId(uint256 x, uint256 y) public pure returns(uint256) {
        return y * 1000 + x;
    }

    function getBlockId(uint256 id_) public view returns(uint256) {
        (uint256 xPixel, uint256 yPixel) = getXY(id_);
        (uint256 xBlock, uint256 yBlock) = pixelXYtoBlockXY(xPixel, yPixel);
        return _blockContract.getId(xBlock, yBlock);

    }

    function pixelXYtoBlockXY(uint256 x_, uint256 y_) public pure returns(uint256,uint256) {
        return (x_/10, y_/10);
    } 

    function color(uint256 id_) public view returns(uint24){
        return _color[id_];
    }

    function exists(uint256 id_) public view returns(bool) {
        return _exists[id_];
    }

    function getCanvasRow(uint256 row_)
        external
        view
        returns (uint24[] memory)
    {
        require(row_ <= 999, "Pixel: Row index out of range");

        uint24[] memory cv = new uint24[](1000);
        for (uint256 i = 0; i < 1000; i++) {
            cv[i] = _color[i + row_*1000];
        }
        return cv;
    }

    function pixelOwner(uint256 id_) external view returns(address){
        return _pixelOwner[id_];
    }

    function fairValue(uint256 id_) public view returns(uint256) {
        return _blockContract.costPerPixel(getBlockId(id_));
    }

    function blockContract() external view returns(address){
        return address(_blockContract);
    }

    function withdraw() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    function setBlockContract(address contractAddress_) external onlyOwner {
        require(!_blockContractAlreadySet, "Pixel: Block contract already set");
        _blockContract = Block(contractAddress_);
        _blockContractAlreadySet = true;

    }


    function _asSingletonArrayUINT24(uint24 element) private pure returns (uint24[] memory) {
        uint24[] memory array = new uint24[](1);
        array[0] = element;

        return array;
    }

    function _asSingletonArrayUINT256(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for(uint256 i=0; i<ids.length; i++) {
            _pixelOwner[ids[i]] =  to;
        }
    }
}
