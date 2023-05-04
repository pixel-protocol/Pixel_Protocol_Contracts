// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pixel is ERC1155, Ownable{
    uint256 private constant INVERSE_COLOR = 16777216;
    uint256 private constant ID_LIMIT = 999999;
    uint256 private constant COST = 1e9;
    mapping(uint256=> uint24) private _color;
    mapping(uint256 => bool) private _exists;

    event ColorChange(address indexed caller, uint256[] ids, uint24[] colors);

    constructor() ERC1155(""){
    }

    function mint(uint256 id_,uint24 color_) public payable {
        require(msg.value >= COST, "Pixel: Insufficient amount");
        require(!_exists[id_], "Pixel: pixel already minted");
        require(id_<= ID_LIMIT, "Pixel: ID out of range");
        _exists[id_] = true;
        _color[id_] = color_;
        _mint(msg.sender, id_, 1,"");
        emit ColorChange(msg.sender,_asSingletonArrayUINT256(id_), _asSingletonArrayUINT24(color_));
        
        
    }


    function mint(uint24[] memory colors_, uint256[] memory ids_) public payable {
        require(colors_.length == ids_.length, "Pixel: Array lengths mismatch");
        require(ids_.length<=100, "Pixel: Batch limit exceeded");
        require(msg.value >= COST * ids_.length, "Pixel: Insufficient amount");

        for (uint256 i = 0; i < ids_.length; i++) {
            if(_exists[ids_[i]]) {
                revert("Pixel: pixel already minted");
            }
            if(ids_[i] > ID_LIMIT) {
                revert("Pixel: ID out of range");
            }
        }

        uint256[] memory ones = new uint256[](ids_.length);
        for (uint256 i = 0; i < ids_.length; i++) {
            _exists[ids_[i]] = true;
            _color[ids_[i]] = colors_[i];
            ones[i] = 1;
        }
        _mintBatch(msg.sender, ids_, ones, "");
        emit ColorChange(msg.sender, ids_, colors_);
    }

    function transform(uint24 color_, uint256 id_) public payable{
        require(msg.value >= COST / 100, "Pixel: Insufficient amount");
        require(_exists[id_], "Pixel: pixel not minted");
        _color[id_] = color_;
        emit ColorChange(msg.sender,_asSingletonArrayUINT256(id_), _asSingletonArrayUINT24(color_));
    }

    function transform(uint24[] memory colors_, uint256[] memory ids_) public payable{
        require(colors_.length == ids_.length, "Pixel: Array lengths mismatch");
        require(ids_.length<=100, "Pixel: Batch limit exceeded");
        require(msg.value >= COST / 100 * ids_.length, "Pixel: Insufficient amount");
        for (uint256 i = 0; i < ids_.length; i++) {
            if(!_exists[ids_[i]]) {
                revert("Pixel: pixel not minted");
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

    function color(uint256 id_) public view returns(uint24){
        return _color[id_];
    }

    function exists(uint256 id_) public view returns(bool) {
        return _exists[id_];
    }

    function getCanvasRow(uint256 row_)
        public
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

    function withdraw() public onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
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

    function cost() public pure returns (uint256) {
        return COST;
    }
}
