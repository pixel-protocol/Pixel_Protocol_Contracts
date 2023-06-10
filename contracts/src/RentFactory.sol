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
    

    event RentPoolCreation(uint256 indexed id, address indexed pool, address creator);

    uint256 private constant ID_LIMIT = 9999;
    Pixel private constant _pixelContract = Pixel(0x4bf4F110dB84e87d4cA89FAd14A47Aa2B8CA3499);
    Block private constant _blockContract = Block(0xbDb7c44fE4fcfC380EecB40ae237360285B55D2d);
    StakedPixel private constant _stakedPixelContract = StakedPixel(0x430308df4D91e07384c71Af8c4deA4200C05B298);
    StakedBlock private constant _stakedBlockContract = StakedBlock(0x46e0FF7458674648b83b5cAf127d84e522B3e6Ad);
    RentUpkeepManager private constant _rentUpkeepManagerContract = RentUpkeepManager(0x6cC3d89B3086Dc59A44FEa975ca6d414342DE1e2);

    mapping(uint256 =>address) private _rentPoolContract; /// Block ID => Rent Pool Address
    mapping(uint256 => uint256) private _upkeepId;

    constructor() {}

    /// @notice Block owner can create a rent pool for the respective block
    /// @dev Function is only callable to block owner
    function createRentPool(uint256 id_, uint256 baseFloorBidPerPixel_, uint256 bidDuration_, uint256 bidIncrement_) external {
        require(_rentPoolContract[id_]==address(0), "RentFactory: Rent Pool already exists");
        require(_blockContract.ownerOf(id_) == msg.sender, "RentFactory: Not the Block owner");
        require(id_ <= ID_LIMIT, "RentFactory: Invalid Block ID");
        require(bidDuration_ >= 3 && bidDuration_ <= 7, "RentFactory: Bid duration out of range");
        require(bidIncrement_ >= 5 && bidIncrement_ <= 20 , "RentFactory: Bid increment out of range");
        require(baseFloorBidPerPixel_ >= _blockContract.costPerPixel(id_), "RentFactory: Base floor bid per pixel out of range");

    
        RentPool rentPool = new RentPool(id_, baseFloorBidPerPixel_, bidDuration_, bidIncrement_, address(this));
        _rentPoolContract[id_] = address(rentPool);
        _stakedBlockContract.registerPool(address(rentPool));
        _stakedPixelContract.registerPool(address(rentPool));

        uint256 upkeepId = _rentUpkeepManagerContract.addKeeper(address(rentPool));
        _upkeepId[id_] = upkeepId;

        emit RentPoolCreation(id_, address(rentPool), msg.sender);

    }

    function getPoolAddress(uint256 id_) public view returns(address){
        return address(_rentPoolContract[id_]);
    }

    function getPoolUpkeep(uint256 id_) public view returns(uint256 upkeepId) {
        upkeepId = _upkeepId[id_];
    }
}
