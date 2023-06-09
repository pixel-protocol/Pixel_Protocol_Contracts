// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Block.sol";

contract Pixel is ERC721B, Ownable {
    error Pixel__OnlyBlock();
    error Pixel__NotMinted(uint256 id);
    error Pixel__InvalidId(uint256 num);
    error Pixel__NotPixelOwner(uint256 id, address caller);
    error Pixel__ArrayLengthMismatch();
    error Pixel__RowIndexOutOfRange();
    error Pixel__BatchLimitExceeded();
    error Pixel__BlockAlreadySet();

    uint24 private constant INVERSE_COLOR = 16777215;
    uint256 private constant ID_LIMIT = 999999;

    Block private _blockContract;
    bool private _blockContractAlreadySet;

    /// @dev Inverted color = 16777215 - actual color
    /// For example, the inverted color is 0 for white and 16777215 for white
    /// This is so that when a pixel is not minted, or the color not set, the default color is white
    mapping(uint256 => uint24) private _invertedColor;

    event ColorChange(address indexed changer, uint256[] ids, uint24[] colors);

    constructor() ERC721B("Pixel", "PIXEL"){
    }

    /// @dev Function is only callable from the Block contract
    function mint(uint24[] memory colors_, uint256[] memory ids_, address buyer_) external {
        if (msg.sender!=address(_blockContract)) revert Pixel__OnlyBlock();
        uint256 numPixels = ids_.length;
        for (uint256 i = 0; i < numPixels;) {
            if(ids_[i] > ID_LIMIT) revert Pixel__InvalidId(ids_[i]);
            _invertedColor[ids_[i]] = INVERSE_COLOR - colors_[i];
            unchecked{
                ++i;
            }
        }
        _mintBatch(buyer_, ids_);
        emit ColorChange(buyer_, ids_, colors_);
    }

    /// @notice Changes the color of a pixel
    function transform(uint24 color_, uint256 id_) external {
        if(id_ > ID_LIMIT) revert Pixel__InvalidId(id_);
        if(!_exists(id_)) revert Pixel__NotMinted(id_);
        if(msg.sender!= ownerOf(id_)) revert Pixel__NotPixelOwner(id_, msg.sender);
        _invertedColor[id_] = INVERSE_COLOR - color_;
        emit ColorChange(msg.sender,_asSingletonArrayUINT256(id_), _asSingletonArrayUINT24(color_));
    }

    /// @notice Changes the color of a batch of pixels
    function transform(uint24[] memory colors_, uint256[] memory ids_) external {
        if(colors_.length != ids_.length) revert Pixel__ArrayLengthMismatch();
        if(ids_.length>100) revert Pixel__BatchLimitExceeded();

        uint256 numPixels = ids_.length;

        for (uint256 i = 0; i < numPixels;) {
            if(ids_[i] > ID_LIMIT) revert Pixel__InvalidId(ids_[i]);
            if(!_exists(ids_[i])) revert Pixel__NotMinted(ids_[i]);
            if (msg.sender != ownerOf(ids_[i])) revert Pixel__NotPixelOwner(ids_[i], msg.sender);      

            unchecked{
                ++i;
            }
        }        

        for (uint256 i = 0; i < numPixels;) {
            _invertedColor[ids_[i]] = INVERSE_COLOR - colors_[i];

            unchecked{
                ++i;
            }
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
        return INVERSE_COLOR - _invertedColor[id_];
    }

    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }

    function getCanvasRow(uint256 row_)
        external
        view
        returns (uint24[] memory)
    {
        if(row_ > 999) revert Pixel__RowIndexOutOfRange();

        uint24[] memory cv = new uint24[](1000);
        for (uint256 i = 0; i < 1000;) {
            cv[i] = INVERSE_COLOR -  _invertedColor[i + row_*1000];
            unchecked {
                ++i;
            }
        }
        return cv;
    }

    /// @notice Also the initial mint price of a pixel
    function fairValue(uint256 id_) public view returns(uint256) {
        return _blockContract.costPerPixel(getBlockId(id_));
    }

    function blockContract() external view returns(address){
        return address(_blockContract);
    }
    
    function setBlockContract(address contractAddress_) external onlyOwner {
        if(_blockContractAlreadySet) revert Pixel__BlockAlreadySet();
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
}
