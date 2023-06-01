// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentFactory.sol";

contract StakedPixel is ERC721B, Ownable {

    bool _factoryIsSet;

    RentFactory private _rentFactoryContract;

    mapping(address => bool) private _isRentPool;


    uint256 private constant ID_LIMIT = 999999;


    constructor() ERC721B("stPixel","stPIXEL") {}

    function mint(uint256 id_, address recipient_) external {
        require(_isRentPool[msg.sender], "StakedPixel: Caller is not a Rent Pool");
        require(!_exists(id_), "StakedPixel: Pixel already exists!");
        require(id_ <= ID_LIMIT, "StakedPixel: Invalid ID");

        _mint(recipient_, id_);        
    }

    function mint(uint256[] memory ids_, address recipient_) external {
        require(_isRentPool[msg.sender], "StakedPixel: Caller is not a Rent Pool");
        for(uint256 i=0;i<ids_.length;i++){
            if(_exists(ids_[i]) || ids_[i] > ID_LIMIT){
                revert("StakedPixel: Pixel already exists!");
            }
        }
        _mintBatch(recipient_, ids_);        
    }

    function burn(uint256 id_) external {
        require(_isRentPool[msg.sender], "StakedPixel: Caller is not a Rent Pool");
        require(_exists(id_), "StakedPixel: Pixel does not exists!");
        _burn(id_);
    }

    function burn(uint256[] memory ids_) external {
        require(_isRentPool[msg.sender], "StakedPixel: Caller is not a Rent Pool");
        for(uint256 i=0;i<ids_.length;i++){
            if(!_exists(ids_[i])){
                revert("StakedPixel: Pixel does not exists!");
            }
        }
        _burnBatch(msg.sender, ids_);
    }

    function registerFactory(address rentFactoryContract_) external onlyOwner {
        require(!_factoryIsSet, "StakedPixel: Factory is set");
        _rentFactoryContract = RentFactory(rentFactoryContract_);
        _factoryIsSet = true;
    }
    function registerPool(address poolContract_) external {
        require(msg.sender == address(_rentFactoryContract), "StakedPixel: Permission Denied");
        _isRentPool[poolContract_] = true;
    }    

    
    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }
}
