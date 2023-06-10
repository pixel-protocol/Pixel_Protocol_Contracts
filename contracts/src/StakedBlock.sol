// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentFactory.sol";

contract StakedBlock is ERC721, Ownable {

    bool _factoryIsSet;

    RentFactory private _rentFactoryContract;

    mapping(address => bool) private _isRentPool;

    uint256 private constant ID_LIMIT = 9999;


    constructor() ERC721("stBlock","stBLOCK"){}

    function mint(uint256 id_, address recipient_) external {
        require(_isRentPool[msg.sender], "StakedBlock: Caller is not a Rent Pool");
        require(!_exists(id_), "StakedBlock: Block already exists!");
        require(id_ <= ID_LIMIT, "StakedBlock: Invalid ID");

        _safeMint(recipient_, id_);
    }

    function burn(uint256 id_) external {
        require(_isRentPool[msg.sender], "StakedBlock: Caller is not a Rent Pool");
        require(_exists(id_), "StakedBlock: Block does not exists!");

        _burn(id_);
    }

    function registerFactory(address rentFactoryContract_) external onlyOwner {
        require(!_factoryIsSet, "StakedBlock: Factory is set");
        _rentFactoryContract = RentFactory(rentFactoryContract_);
        _factoryIsSet = true;
    }

    function registerPool(address poolContract_) external {
        require(msg.sender == address(_rentFactoryContract), "StakedBlock: Caller is not Rent Factory");
        _isRentPool[poolContract_] = true;
    }    

    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }
}
