// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pixel.sol";
import "./Block.sol";
import "./RentPool.sol";
import "./StakedBlock.sol";
import "./StakedPixel.sol";
import "./RentUpkeepManager.sol";

contract RentFactory is Ownable {
    

    event CreatePool(uint256 indexed id, address pool, address creator);

    uint256 private constant ID_LIMIT = 9999;
    Pixel private constant _pixelContract = Pixel(0x92a5EC81F857fA8C3cF9391325344136770d4cb7);
    Block private constant _blockContract = Block(0x1bf38885692c161aBc0CfFDb53A786947D80C396);
    StakedPixel private constant _stakedPixelContract = StakedPixel(0xC9980afDDC4fE31a78D8B4c6567bb3920CA10a31);
    StakedBlock private constant _stakedBlockContract = StakedBlock(0x5D67d0d2a300b79caF5b9B48F296068Da3D37c11);
    RentUpkeepManager private constant _rentUpkeepManagerContract = RentUpkeepManager(0x3F2dd7ed9baC6E22cd80Ef765f1fCce6833700CE);

    mapping(uint256 =>address) private _rentPoolContract; // Block ID => Rent Pool Address
    mapping(uint256 => uint256) private _upkeepId;

    constructor() {}

    function createRentPool(uint256 id_, uint256 initialBaseCostPerPixel_, uint256 cooldownDuration_, uint256 bidIncrement_) external {
        require(_rentPoolContract[id_]==address(0), "RentFactory: Rent Pool already exists");
        require(_blockContract.ownerOf(id_) == msg.sender, "RentFactory: Not the Block owner");
        require(id_ <= ID_LIMIT, "RentFactory: Invalid Block ID");
        require(cooldownDuration_ > 0 && cooldownDuration_ <= 7, "RentFactory: Cooldown duration out of range");
        require(bidIncrement_ > 0 && bidIncrement_ <= 20 , "RentFactory: Bid increment out of range");
        require(initialBaseCostPerPixel_ >= _blockContract.costPerPixel(id_), "RentFactory: Initial base cost per pixel < cost per pixel");

    
        RentPool rentPool = new RentPool(id_, initialBaseCostPerPixel_, cooldownDuration_, bidIncrement_, address(this));
        _rentPoolContract[id_] = address(rentPool);
        _stakedBlockContract.registerPool(address(rentPool));
        _stakedPixelContract.registerPool(address(rentPool));

        uint256 upkeepId = _rentUpkeepManagerContract.addKeeper(address(rentPool));
        _upkeepId[id_] = upkeepId;

        emit CreatePool(id_, address(rentPool), msg.sender);

    }

    function getPoolAddress(uint256 id_) public view returns(address){
        return address(_rentPoolContract[id_]);
    }

    function getPoolUpkeep(uint256 id_) public view returns(uint256 upkeepId) {
        upkeepId = _upkeepId[id_];
    }
}
