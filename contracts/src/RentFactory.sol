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
    error RentFactory__PoolAlreadyExists(uint256 id);
    error RentFactory__NotBlockOwner(uint256 id, address caller);
    error RentFactory__InvalidBlockId(uint256 num);
    error RentFactory__BidDurationOutOfRange();
    error RentFactory__BidIncrementOutOfRange();
    error RentFactory__BaseFloorBidPerPixelOutOfRange();

    event RentPoolCreation(uint256 indexed id, address indexed pool, address creator);

    uint256 private constant ID_LIMIT = 9999;
    Pixel private constant _pixelContract = Pixel(0x1c13c57fE0A118a1DB9e83f2B39D2b4C74B04EB6);
    Block private constant _blockContract = Block(0xAca027EE6ee11E2b8B076f4D63422fE2735B4F48);
    StakedPixel private constant _stakedPixelContract = StakedPixel(0xA224ad2C763fcb3937176b50Bf776909Ad689AE6);
    StakedBlock private constant _stakedBlockContract = StakedBlock(0x04E53c97a69975564fbf1340F06CcE15EA3DED8D);
    RentUpkeepManager private constant _rentUpkeepManagerContract = RentUpkeepManager(0x0C80a6Cada622B6864A9Ef0189385CdAfD79E641);

    mapping(uint256 =>address) private _rentPoolContract; /// Block ID => Rent Pool Address
    mapping(uint256 => uint256) private _upkeepId;

    constructor() {}

    /// @notice Block owner can create a rent pool for the respective block
    /// @dev Function is only callable to block owner
    function createRentPool(uint256 id_, uint256 baseFloorBidPerPixel_, uint256 bidDuration_, uint256 bidIncrement_) external {
        if(_rentPoolContract[id_]!=address(0)) revert RentFactory__PoolAlreadyExists(id_);
        if(_blockContract.ownerOf(id_) != msg.sender) revert RentFactory__NotBlockOwner(id_, msg.sender);
        if(id_ > ID_LIMIT) revert RentFactory__InvalidBlockId(id_);

        if(bidDuration_ < 3 || bidDuration_ > 7) revert RentFactory__BidDurationOutOfRange();
        if(bidIncrement_ < 5 || bidIncrement_ > 20) revert RentFactory__BidIncrementOutOfRange();
        if(baseFloorBidPerPixel_ < _blockContract.costPerPixel(id_)) revert RentFactory__BaseFloorBidPerPixelOutOfRange();

    
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
