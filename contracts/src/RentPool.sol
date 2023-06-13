// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

import "./Pixel.sol";
import "./Block.sol";
import "./StakedBlock.sol";
import "./StakedPixel.sol";
import "./RentFactory.sol";

enum Duration {
        THIRTY,
        NINETY,
        HUNDRED_AND_EIGHTY
    }

enum PoolState {
    DORMANT,
    ACTIVE,
    PENDING,
    ONGOING,
    ENDED
}

struct EpochMetadata {
    uint256 epoch;
    uint256 numBids;
    uint256 biddingStartDate;
    uint256 biddingEndDate;
    uint256 startDate;
    uint256 endDate;
    uint256 bidPerPixel;
    uint24[] colors;
    address tenant;
    Duration duration;
}

/// @dev A RentPool contract is created for each Block
contract RentPool is Ownable, IERC721Receiver, AutomationCompatibleInterface {
    error RentPool__InvalidState(PoolState expected, PoolState actual);
    error RentPool__BidDurationOutOfRange();
    error RentPool__BidIncrementOutOfRange();
    error RentPool__BaseFloorBidPerPixelOutOfRange();
    error RentPool__NotBlockOwner(uint256 id);
    error RentPool__NotStakedBlockOwner(uint256 id);
    error RentPool__InsufficientBid(uint256 minimum, uint256 actual);
    error RentPool__Bidder();
    error RentPool__NotBidder();
    error RentPool__InsufficientETH(uint256 expected, uint256 actual);
    error RentPool__BiddingNotEnded();
    error RentPool__EpochNotCloseable();
    error RentPool__DurationOutOfRange();
    error RentPool__PixelNotOwnedByBlock(uint256 id);
    error RentPool__NotPixelOwner(uint256 id);
    error RentPool__NotStakedPixelOwner(uint256 id);

    RentFactory private immutable _rentFactoryContract;
    Pixel private constant _pixelContract = Pixel(0x4bf4F110dB84e87d4cA89FAd14A47Aa2B8CA3499);
    Block private constant _blockContract = Block(0xbDb7c44fE4fcfC380EecB40ae237360285B55D2d);
    StakedPixel private constant _stakedPixelContract = StakedPixel(0x430308df4D91e07384c71Af8c4deA4200C05B298);
    StakedBlock private constant _stakedBlockContract = StakedBlock(0x46e0FF7458674648b83b5cAf127d84e522B3e6Ad);

    uint256 private _blockId;
    uint256[] private _pixelIds;


    /// @notice The current state of the pool.
    /// Dormant: Pool is not accepting bids. Block owner needs to activate the pool in order to change the state to 'Active'.
    /// Active: Pool is accepting bids but no bids currently.
    /// Pending: Once a bid is made to the pool, pool becomes Pending. Pool will remain pending within the bid duration.
    /// Ongoing: On permissionless function trigger when bid duration is over and there is >= 1 bid, pool state becomes 'Ongoing'. The rent period officially begins.
    /// Ended: Rent period ends, Chainlink Automation will change pool state to 'Ended'
    PoolState public _poolState;

    /// @notice Floor price per pixel in a THIRTY days rent
    uint256 public _baseFloorBidPerPixel;

    /// @notice Number of days from the first bid to the end of the bidding period
    uint256 public _bidDuration;

    /// @notice (current bid) * (1+ _bidIncrement) = Minimum amount of next bid
    uint256 public _bidIncrement;
    
    /// @notice Number of past/present rent instances OR id of last/current rent instance
    uint256 public _epoch;

    /// @notice Cumulative unclaimed rewards belonging to the Block
    uint256 public _blockReward;

    /// @notice Cumulative unclaimed rewards belonging to each Pixel
    /// @dev Mapping from pixelId to the reward amount
    mapping(uint256 => uint256) public _pixelReward;

    /// @notice Array of metadata of past epochs
    EpochMetadata[] public _epochs;


    /// @dev Epoch specific variables that will be deleted in the _deleteEpochStates() function

    /// @notice Floor price per pixel for current rent epoch
    uint256 public _floorBidPerPixel;

    /// @notice Number of bids submitted
    uint256 public _numBids;

    /// @notice Time of the first bid
    uint256 public _biddingStartDate;

    /// @notice Time at end of bid duration. Users will be able to call the initiate() function from the next block onwards
    uint256 public _biddingEndDate;

    /// @notice Start of the rent period. Also the time at which initiate() is called.
    uint256 public _startDate;

    /// @notice End of the rent period.
    uint256 public _endDate;

    /// @notice Floor price per pixel of the latest bid, and eventually the winning bid
    uint256 public _finalBidPerPixel;

    /// @dev Mapping from the bid Id to the address of the bidder
    mapping(uint256 => address) public _bidToBidder;

    /// @dev Mapping from the bidder to their latest bid
    mapping(address => uint256) public _bidderToLastBid;

    /// @dev Mapping from the bid Id to the colors of the corresponding bid
    mapping(uint256 => uint24[]) public _bidColors;

    /// @dev Mapping from the bid Id to the bid price of the corresponding bid
    mapping(uint256 => uint256) public _bidPerPixel;

    /// @dev Original state of the Pixels
    uint24[] public _origColors;

    /// @dev Duration of the rent period
    Duration public _duration;

    event PoolStateChange(uint256 indexed epoch, PoolState indexed previous, PoolState indexed current);
    event Reward(uint256 indexed epoch, uint256 blockReward, uint256 pixelReward);

    constructor(uint256 id_, uint256 baseFloorBidPerPixel_, uint256 bidDuration_, uint256 bidIncrement_, address rentFactoryContract_) {
        _rentFactoryContract = RentFactory(rentFactoryContract_);   
        _poolState = PoolState.DORMANT;
        _bidDuration = bidDuration_;
        _baseFloorBidPerPixel= baseFloorBidPerPixel_;
        _bidIncrement = bidIncrement_;
        _blockId = id_;
        _pixelIds = _blockContract.getPixelIds(id_);
        _epoch++; /// 1-based indexing: first epoch takes on index 1
    }

    /// @notice monitors if upkeep is needed
    /// Chainlink Automation will trigger the upkeep if the following conditions are met:
    /// 1. Rent period has ended 2. Rent is still shown as ongoing
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded =  (_poolState == PoolState.ONGOING) && (block.timestamp > _endDate);

        uint256 totalRewards = _finalBidPerPixel * 100;

        uint256 blockReward = totalRewards * 20 / 100; /// 20% goes to block

        uint256 pixelRewards = totalRewards - blockReward;

        uint256 blockRewardAfterFees = blockReward * 98 / 100; /// 2% protocol fee

        uint256 pixelRewardsAfterFees = pixelRewards * 98 / 100; /// 2% protocol fee

        uint256 pixelRewardAfterFees = pixelRewardsAfterFees / 100;  

        performData = abi.encode(blockRewardAfterFees, pixelRewardAfterFees);
        
    }

    /// @notice Performs 3 upkeeps
    /// 1. Set pool state to Ended
    /// 2. Set the pending block reward and pending pixel reward
    /// 3. Revert the colors of the pixels to their original state
    function performUpkeep(bytes calldata performData) external override {
        /// @dev We highly recommend revalidating the upkeep in the performUpkeep function
        if ((_poolState == PoolState.ONGOING) && (block.timestamp > _endDate)) {
            (uint256 blockRewardAfterFees, uint256 pixelRewardAfterFees) = abi.decode(performData, (uint256,uint256));

            _blockReward += blockRewardAfterFees;
            
            for(uint256 i = 0; i < 100;) {
                _pixelReward[_pixelIds[i]] += pixelRewardAfterFees;

                unchecked {
                    i++;
                }
            }

            _poolState = PoolState.ENDED;
            _pixelContract.transform(_origColors, _pixelIds);

            emit PoolStateChange(_epoch, PoolState.ONGOING, PoolState.ENDED);
        }
    }

    modifier onlyBlockOrStakedBlockOwner() {
        uint256 blockId = _blockId;
        if(_stakedBlockContract.exists(blockId)){
            if(_stakedBlockContract.ownerOf(blockId) != msg.sender) revert RentPool__NotStakedBlockOwner(blockId);
        } else {
            if(_blockContract.ownerOf(blockId) != msg.sender) revert RentPool__NotStakedBlockOwner(blockId);
        }
        _;
    }

    function adjustPoolParameters( uint256 baseFloorBidPerPixel_, uint256 bidDuration_, uint256 bidIncrement_) external onlyBlockOrStakedBlockOwner {
        if(_poolState != PoolState.DORMANT) revert RentPool__InvalidState(PoolState.DORMANT, _poolState);
        
        if(bidDuration_ != 0 && (bidDuration_ < 3 || bidDuration_ > 7)) revert RentPool__BidDurationOutOfRange();
        if(bidIncrement_ != 0 && (bidIncrement_ < 5 || bidIncrement_ > 20)) revert RentPool__BidIncrementOutOfRange();
        if(baseFloorBidPerPixel_ != 0 && (baseFloorBidPerPixel_ < _blockContract.costPerPixel(_blockId))) revert RentPool__BaseFloorBidPerPixelOutOfRange();
        if(bidDuration_ != 0) {
            _bidDuration = bidDuration_;
        }

        if(bidIncrement_ != 0) {
            _bidIncrement = bidIncrement_;
        }

        if(baseFloorBidPerPixel_ != 0) {
            _baseFloorBidPerPixel = baseFloorBidPerPixel_;
        }

    }

    /// @notice Permissionless function that can be called by anyone to close the current epoch
    function closeEpoch() external {
        if(_poolState != PoolState.ENDED) revert RentPool__InvalidState(PoolState.ENDED, _poolState);

        if(block.timestamp <= _endDate + 7 * 1 days) revert RentPool__EpochNotCloseable();
        
        _epoch++; /// start new epoch
        _deleteEpochStates();
        _poolState = PoolState.DORMANT;

        emit PoolStateChange(_epoch, PoolState.ENDED, PoolState.DORMANT);

    }

    /// @notice Activate the rent pool in order to start accepting bids
    function activate(uint256 duration_) external onlyBlockOrStakedBlockOwner {
        if(_poolState != PoolState.DORMANT) revert RentPool__InvalidState(PoolState.DORMANT, _poolState);

        if(duration_ > 2) revert RentPool__DurationOutOfRange();

        _duration = _mapNumToDuration(duration_);
        _floorBidPerPixel = getFloorBidPerPixel(duration_);

        _poolState = PoolState.ACTIVE;

        emit PoolStateChange(_epoch, PoolState.DORMANT, PoolState.ACTIVE);
    }

    /// @notice Deactivate the rent pool in order to stop accepting bids
    function deactivate() external onlyBlockOrStakedBlockOwner{
        if(_poolState != PoolState.ACTIVE) revert RentPool__InvalidState(PoolState.ACTIVE, _poolState);
        _poolState = PoolState.DORMANT;

        emit PoolStateChange(_epoch, PoolState.ACTIVE, PoolState.DORMANT);

    }

    /// @notice Permissionless function, called when bidding period ends to initiate the rent epoch. 
    /// External caller will be rewarded with 0.5% of all bids.
    function initiate() external {
        if(_poolState != PoolState.PENDING) revert RentPool__InvalidState(PoolState.PENDING, _poolState);

        if(block.timestamp <= _biddingEndDate) revert RentPool__BiddingNotEnded();
        
        if(!isFullyStaked()) {
            _poolState = PoolState.ACTIVE; /// Revert back to ACTIVE state

            /// Refund all bidders and set to active - epoch cancelled
            for(uint256 i = 1; i < _numBids + 1;){
                address bidder = _bidToBidder[i];
                uint256 lastBid = _bidderToLastBid[bidder];

                if(lastBid == i) {
                    uint256 bid = _bidPerPixel[i] * 100;
                    uint256 tax = bid * 5 / 1000; /// 0.5%
                    uint256 toBidder = bid - tax;
                    uint256 toCaller = tax;

                    payable(bidder).transfer(toBidder);
                    payable(msg.sender).transfer(toCaller);
                }

                unchecked{
                    i++;
                }
            }
            _deleteEpochStates();

            emit PoolStateChange(_epoch, PoolState.PENDING, PoolState.ACTIVE);
        } else {

            uint24[] memory colors = _bidColors[_numBids];
            _origColors = _blockContract.getPixelColors(_blockId);
            _startDate = block.timestamp;
            uint256 numDays = (_duration==Duration.THIRTY) ? 30 : (_duration==Duration.NINETY) ? 90 : 180;
            _endDate = _startDate + numDays;
            address tenant = _bidToBidder[_numBids];
            EpochMetadata memory metadata = EpochMetadata(_epoch, _numBids, _biddingStartDate, _biddingEndDate, _startDate, _endDate, _finalBidPerPixel, colors, tenant, _duration);
            _epochs.push(metadata);
            _pixelContract.transform(colors, _pixelIds);
            
            _poolState = PoolState.ONGOING;

            uint256 toCaller = 0;

            /// Refund all bidders except for last bidder
            for(uint256 i = 1; i < _numBids;){
                address bidder = _bidToBidder[i];
                uint256 lastBid = _bidderToLastBid[bidder];

                if(lastBid == i) {
                    uint256 bid = _bidPerPixel[i] * 100;
                    uint256 tax = bid * 5 / 1000; /// 0.5% goes to caller
                    uint256 toBidder = bid - tax;
                    toCaller += tax;

                    payable(bidder).transfer(toBidder);
                }

                unchecked{
                    i++;
                }
            }

            payable(msg.sender).transfer(toCaller);

            emit PoolStateChange(_epoch, PoolState.PENDING, PoolState.ONGOING);
            
        }
    }

    /// @notice For caller to make their first bid in the rent epoch
    function makeBid(uint256 bidPerPixel_, uint24[] memory colors_) external payable {
        if(_poolState != PoolState.ACTIVE && _poolState!= PoolState.PENDING) revert RentPool__InvalidState(PoolState.ACTIVE, _poolState);
        uint256 minBid = getMinNextBid();
        if (bidPerPixel_ < minBid) revert RentPool__InsufficientBid(minBid, bidPerPixel_);

        if(msg.value < bidPerPixel_ * 100) revert RentPool__InsufficientETH(bidPerPixel_*100, msg.value);
        if(isBidder(msg.sender)) revert RentPool__Bidder();

        _storeBid(colors_, msg.sender, bidPerPixel_);

        if(_poolState == PoolState.ACTIVE) {
            _poolState = PoolState.PENDING;
        
            /// Update epoch variables
            _biddingStartDate = block.timestamp;
            _biddingEndDate = _biddingStartDate + _bidDuration * 1 days;

            emit PoolStateChange(_epoch, PoolState.ACTIVE, PoolState.PENDING);
        }
    }

    /// @notice For caller with existing bid(s) to update their bid
    function updateBid(uint256 newBidPerPixel_, uint24[] memory colors_, bool isColorChanged) external payable {
        if(_poolState != PoolState.PENDING) revert RentPool__InvalidState(PoolState.PENDING, _poolState);
        uint256 minBid = getMinNextBid();
        if (newBidPerPixel_ < minBid) revert RentPool__InsufficientBid(minBid, newBidPerPixel_);

        if(!isBidder(msg.sender)) revert RentPool__NotBidder();

        uint256 key = _bidderToLastBid[msg.sender];

        uint256 diffToTopUp = newBidPerPixel_ - _bidPerPixel[key];

        if(msg.value < diffToTopUp * 100) revert RentPool__InsufficientETH(diffToTopUp*100, msg.value);

        if(isColorChanged){
            _storeBid(colors_, msg.sender, newBidPerPixel_);
        }
        else {
            _storeBid(_bidColors[key], msg.sender, newBidPerPixel_);
        }
    }

    /// @notice Pixel owner stakes their pixels and in return, receives an stPIXEL (Staked Pixel) for each pixels staked 
    /// @dev Caller needs to approve their Pixel(s) first before calling the function (i.e. ERC721.setApprovalForAll)
    function stakePixel(uint256[] memory ids_) external {
        uint256 numPixels = ids_.length;
        for(uint256 i = 0; i < numPixels;) {
            if(_pixelContract.getBlockId(ids_[i]) != _blockId) revert RentPool__PixelNotOwnedByBlock(ids_[i]);
            if(_pixelContract.ownerOf(ids_[i]) != msg.sender) revert RentPool__NotPixelOwner(ids_[i]);
            unchecked {
                i++;
            }
        }

        _pixelContract.transferFrom(msg.sender, address(this), ids_);
        
        _stakedPixelContract.mint(ids_, msg.sender);
        
    }

    /// @notice Pixel owner unstakes their pixels by sending the stPIXEL (Staked Pixel) equivalent to the contract, which will then be burned by the contract. In return, they receive back the pixels they staked in the contract
    function unstakePixelWithRewards(uint256[] memory ids_) external {
        if(_poolState == PoolState.PENDING || _poolState == PoolState.ONGOING) revert RentPool__InvalidState(PoolState.DORMANT, _poolState);

        uint256 numPixels = ids_.length;

        for(uint256 i = 0; i < numPixels;) {
            if(_stakedPixelContract.ownerOf(ids_[i]) != msg.sender) revert RentPool__NotStakedPixelOwner(ids_[i]);
            unchecked {
                i++;
            }
        }

        uint256 reward = 0;

        for(uint256 i=0;i<numPixels;) {
            reward += _pixelReward[ids_[i]];
            delete _pixelReward[ids_[i]];
            unchecked {
                i++;
            }
        }

        _stakedPixelContract.burn(ids_);
        _pixelContract.transferFrom(address(this), msg.sender, ids_);

        payable(_msgSender()).transfer(reward);
        
    }

    /// @notice Block owner stakes their block and in return, receives an stBLOCK (Staked Block)
    /// @dev Caller needs to approve their Block first before calling the function (i.e. ERC721.setApprovalForAll)
    function stakeBlock() external {
        if(
            _blockContract.ownerOf(_blockId) != msg.sender // Caller is Block owner
        ) revert RentPool__NotBlockOwner(_blockId);

         _blockContract.transferFrom(msg.sender, address(this),_blockId);

        _stakedBlockContract.mint(_blockId, msg.sender);
        
    }

    /// @notice Block owner unstakes their block by sending the stBLOCK (Staked Blcok) equivalent to the contract, which will then be burned by the contract. In return, they receive back the block they staked in the contract
    function unstakeBlockWithRewards() external {
        if(_poolState == PoolState.PENDING || _poolState == PoolState.ONGOING) revert RentPool__InvalidState(PoolState.DORMANT, _poolState);
        if(
            _stakedBlockContract.ownerOf(_blockId) != msg.sender // Caller is Block owner
        ) revert RentPool__NotStakedBlockOwner(_blockId);

        uint256 reward = _blockReward;
        delete _blockReward;

        _stakedBlockContract.burn(_blockId);
        _blockContract.transferFrom(address(this),msg.sender,_blockId);

        payable(_msgSender()).transfer(reward);
        
    }

    function isBidder(address account_) public view returns(bool) {
        return _bidderToLastBid[account_] != 0;
    }

    /// @notice Maps rent duration to the floor bid per pixel
    /// 30 days: baseFloorBidPerPixel
    /// 90 days: 2 * baseFloorBidPerPixel
    /// 180 days: 3 * baseFloorBidPerPixel
    function getFloorBidPerPixel(uint256 num_) public view returns(uint256) {
        if(num_>2) {
            return 0;
        }

        return _baseFloorBidPerPixel * (num_ + 1);
    }

    function _mapNumToDuration(uint256 num_) internal pure returns(Duration) {
        if (num_ == 2) {
            return Duration.HUNDRED_AND_EIGHTY;
        } else if (num_ == 1) {
            return Duration.NINETY;
        } else {
            return Duration.THIRTY;
        }
    }

    function getMinNextBid() public view returns(uint256) {
        if(_numBids==0) return _floorBidPerPixel;
        return _bidPerPixel[_numBids] * (100 + _bidIncrement) / 100;
    }

    function isStaked(uint256 id_, bool isBlock_) public view returns(bool) {
        return
        isBlock_ ? _blockContract.ownerOf(_blockId) == address(this) : _pixelContract.ownerOf(id_) == address(this);
    }

    /// @notice Fully Staked: 1 Block + 100 Pixels
    function isFullyStaked() public view returns(bool) {

        for(uint256 i=0; i< 100;) {
            if(_pixelContract.ownerOf(_pixelIds[i]) != address(this)){
                return false;
            }
            unchecked {
                i++;
            }
        }
        return _blockContract.ownerOf(_blockId) == address(this);
    }

    function _storeBid(uint24[] memory colors_, address bidder_, uint256 bidPerPixel_ ) internal {
        
        /// @dev 1-based indexing so that
        /// the default value of zero in the _bidderToLastBid mapping indicates no bid from the user, 
        /// instead of the erroneous fact that the user made the first bid
        _numBids++; 
        _bidColors[_numBids] = colors_;
        _bidToBidder[_numBids] = bidder_;
        _bidderToLastBid[bidder_] = _numBids;
        _bidPerPixel[_numBids] = bidPerPixel_;
        _finalBidPerPixel = bidPerPixel_;
    }

    function _deleteEpochStates() internal {
        uint256 numBids = _numBids;
        delete _floorBidPerPixel;
        delete _duration;
        delete _origColors;
        delete _finalBidPerPixel;
        delete _numBids;
        delete _biddingStartDate;
        delete _biddingEndDate;
        delete _startDate;
        delete _endDate;

        for(uint256 i = 1; i < numBids + 1;) {
            address bidder = _bidToBidder[i];
            delete _bidColors[i];
            delete _bidPerPixel[i];
            delete _bidToBidder[i];
            delete _bidderToLastBid[bidder];
            unchecked {
                i++;
            }
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){}
} 