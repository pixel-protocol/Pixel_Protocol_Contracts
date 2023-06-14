// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentFactory.sol";

contract StakedPixel is ERC721B, Ownable {
    error StakedPixel__NotRentPool();
    error StakedPixel__NotRentFactory();
    error StakedPixel__AlreadyMinted(uint256 id);
    error StakedPixel__NotMinted(uint256 id);
    error StakedPixel__InvalidId(uint256 num);
    error StakedPixel__FactoryAlreadySet();

    bool _factoryIsSet;

    RentFactory private _rentFactoryContract;

    mapping(address => bool) private _isRentPool;


    uint256 private constant ID_LIMIT = 999999;


    constructor() ERC721B("stPixel","stPIXEL") {}

    function mint(uint256 id_, address recipient_) external {
        if(id_ > ID_LIMIT) revert StakedPixel__InvalidId(id_);
        if(!_isRentPool[msg.sender]) revert StakedPixel__NotRentPool();
        if(_exists(id_)) revert StakedPixel__AlreadyMinted(id_);
        

        _mint(recipient_, id_);        
    }

    function mint(uint256[] memory ids_, address recipient_) external {
        if(!_isRentPool[msg.sender]) revert StakedPixel__NotRentPool();
        for(uint256 i=0;i<ids_.length;){
            if(ids_[i] > ID_LIMIT) revert StakedPixel__InvalidId(ids_[i]);
            if(_exists(ids_[i])){
                revert StakedPixel__AlreadyMinted(ids_[i]);
            }

            unchecked{
                ++i;
            }
        }
        _mintBatch(recipient_, ids_);        
    }

    function burn(uint256 id_) external {
        if(!_isRentPool[msg.sender]) revert StakedPixel__NotRentPool();
        if(!_exists(id_)) revert StakedPixel__NotMinted(id_);
        _burn(id_);
    }

    function burn(uint256[] memory ids_) external {
        if(!_isRentPool[msg.sender]) revert StakedPixel__NotRentPool();
        for(uint256 i=0;i<ids_.length;){
            if(!_exists(ids_[i])) revert StakedPixel__NotMinted(ids_[i]);
            unchecked {
                ++i;
            }
        }
        _burnBatch(msg.sender, ids_);
    }

    function registerFactory(address rentFactoryContract_) external onlyOwner {
        if(_factoryIsSet) revert StakedPixel__FactoryAlreadySet();
        _rentFactoryContract = RentFactory(rentFactoryContract_);
        _factoryIsSet = true;
    }
    function registerPool(address poolContract_) external {
        if(msg.sender != address(_rentFactoryContract)) revert StakedPixel__NotRentFactory();
        _isRentPool[poolContract_] = true;
    }

    function getPixelOwners(uint256[] memory ids_) external view returns(address[] memory owners) {
        uint256 length = ids_.length;
        owners = new address[](length);
        
        for(uint256 i = 0; i < length;) {
            if(!_exists(ids_[i])){
                owners[i] = address(0);
                continue;
            }
            owners[i] = ownerOf(ids_[i]);

            unchecked {
                ++i;
            }
        }
    }

    
    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }
}
