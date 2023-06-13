// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentFactory.sol";

contract StakedBlock is ERC721, Ownable {

    error StakedBlock__NotRentPool();
    error StakedBlock__NotRentFactory();
    error StakedBlock__AlreadyMinted(uint256 id);
    error StakedBlock__NotMinted(uint256 id);
    error StakedBlock__InvalidId(uint256 num);
    error StakedBlock__FactoryAlreadySet();

    bool _factoryIsSet;

    RentFactory private _rentFactoryContract;

    mapping(address => bool) private _isRentPool;

    uint256 private constant ID_LIMIT = 9999;


    constructor() ERC721("stBlock","stBLOCK"){}

    function mint(uint256 id_, address recipient_) external {
        if(id_ > ID_LIMIT) revert StakedBlock__InvalidId(id_);
        if(!_isRentPool[msg.sender]) revert StakedBlock__NotRentPool();
        if(_exists(id_)) revert StakedBlock__AlreadyMinted(id_);

        _safeMint(recipient_, id_);
    }

    function burn(uint256 id_) external {
        if(!_isRentPool[msg.sender]) revert StakedBlock__NotRentPool();
        if(!_exists(id_)) revert StakedBlock__NotMinted(id_);

        _burn(id_);
    }

    function registerFactory(address rentFactoryContract_) external onlyOwner {
        if(_factoryIsSet) revert StakedBlock__FactoryAlreadySet();
        _rentFactoryContract = RentFactory(rentFactoryContract_);
        _factoryIsSet = true;
    }

    function registerPool(address poolContract_) external {
        if(msg.sender != address(_rentFactoryContract)) revert StakedBlock__NotRentFactory();
        _isRentPool[poolContract_] = true;
    }    

    function exists(uint256 id_) public view returns(bool) {
        return _exists(id_);
    }
}
