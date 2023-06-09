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

/// @dev A RentPool contract is created for each Block

contract RentPool is Ownable, IERC721Receiver, AutomationCompatibleInterface {

    RentFactory private immutable _rentFactoryContract;
    Pixel private constant _pixelContract = Pixel(0x92a5EC81F857fA8C3cF9391325344136770d4cb7);
    Block private constant _blockContract = Block(0x1bf38885692c161aBc0CfFDb53A786947D80C396);
    StakedPixel private constant _stakedPixelContract = StakedPixel(0xC9980afDDC4fE31a78D8B4c6567bb3920CA10a31);
    StakedBlock private constant _stakedBlockContract = StakedBlock(0x5D67d0d2a300b79caF5b9B48F296068Da3D37c11);

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
        uint256 startDate;
        uint256 endDate;
        uint256 costPerPixel;
        address tenant;
        Duration duration;
    }

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
    uint256 public _initialBaseCostPerPixel;

    /// @notice Number of days from the first bid to the end of the bidding period
    uint256 public _cooldownDuration;

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



    /// @dev Epoch specific variables that will be deleted in the closeEpoch() function

    /// @notice Floor price per pixel for current rent epoch
    uint256 public _initialCostPerPixel;

    /// @notice Number of bids submitted
    uint256 public _numBids;

    /// @notice Time of the first bid
    uint256 public _cooldownStartDate;

    /// @notice Time at end of bid duration. Users will be able to call the initiate() function from the next block onwards
    uint256 public _cooldownEndDate;

    /// @notice Start of the rent period. Also the time at which initiate() is called.
    uint256 public _startDate;

    /// @notice End of the rent period.
    uint256 public _endDate;

    /// @notice Floor price per pixel of the latest bid, and eventually the winning bid
    uint256 public _finalBidCostPerPixel;

    /// @notice Block reward accrued for current reward, will be added to total balance on 1. Unstake 2. Close Epoch
    uint256 public _pendingBlockReward; 

    /// @notice Pixel reward accrued for current reward per pixel, will be added to total balance on 1. Unstake 2. Close Epoch
    uint256 public _pendingPixelReward; 

    /// @dev Mapping from the bid Id to the address of the bidder
    mapping(uint256 => address) public _bidToBidder;

    /// @dev Mapping from the bidder to their latest bid
    mapping(address => uint256) public _bidderToLastBid;

    /// @dev Mapping from the bid Id to the colors of the corresponding bid
    mapping(uint256 => uint24[]) public _bidColors;

    /// @dev Mapping from the bid Id to the bid price of the corresponding bid
    mapping(uint256 => uint256) public _bidCostPerPixel;

    /// @dev Original state of the Pixels
    uint24[] public _origColors;

    /// @dev Duration of the rent period
    Duration public _duration;

    constructor(uint256 id_, uint256 initialBaseCostPerPixel_, uint256 cooldownDuration_, uint256 bidIncrement_, address rentFactoryContract_) {
        _rentFactoryContract = RentFactory(rentFactoryContract_);   
        _poolState = PoolState.DORMANT;
        _cooldownDuration = cooldownDuration_;
        _initialBaseCostPerPixel= initialBaseCostPerPixel_;
        _bidIncrement = bidIncrement_;
        _blockId = id_;
        _pixelIds = _blockContract.getPixelIds(id_);
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

        uint256 totalRewards = _finalBidCostPerPixel;

        uint256 blockReward = totalRewards * 20 / 100; /// 20% goes to block

        uint256 pixelRewards = totalRewards - blockReward;

        uint256 blockRewardAfterFees = blockReward * 98 / 100; /// 2% protocol fee

        uint256 pixelRewardsAfterFees = pixelRewards * 98 / 100; /// 2% protocol fee

        uint256 pixelRewardAfterFees = pixelRewardsAfterFees / 100;  

        performData = abi.encode(blockRewardAfterFees, pixelRewardAfterFees);
        
    }

    /// @notice performs 3 upkeeps
    /// 1. Set pool state to Ended
    /// 2. Set the pending block reward and pending pixel reward
    /// 3. Revert the colors of the pixels to their original state
    function performUpkeep(bytes calldata performData) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((_poolState == PoolState.ONGOING) && (block.timestamp > _endDate)) {
            (uint256 blockRewardAfterFees, uint256 pixelRewardAfterFees) = abi.decode(performData, (uint256,uint256));
            _pendingBlockReward = blockRewardAfterFees;
            _pendingPixelReward = pixelRewardAfterFees;
            _poolState = PoolState.ENDED;
            _pixelContract.transform(_origColors, _pixelIds);
        }
    }

    function adjustPoolParameters( uint256 initialBaseCostPerPixel_, uint256 cooldownDuration_, uint256 bidIncrement_) external {
        require(_poolState == PoolState.DORMANT, "RentPool: Pool must be dormant!");
        require(
            _blockContract.ownerOf(_blockId) == address(this) // Block already in pool
            ||
            _blockContract.ownerOf(_blockId) == msg.sender // Caller is Block owner
            ,
            "RentPool: Block not found or not owned");
        require(cooldownDuration_ == 0 || cooldownDuration_ > 0 && cooldownDuration_ <= 7, "RentPool: Cooldown duration out of range");
        require(bidIncrement_ == 0 || bidIncrement_ > 0 && bidIncrement_ <= 20 , "RentPool: Bid increment out of range");
        require(initialBaseCostPerPixel_ == 0 || initialBaseCostPerPixel_ >= _blockContract.costPerPixel(_blockId), "RentPool: Initial base cost per pixel < cost per pixel");
        if(cooldownDuration_ != 0) {
            _cooldownDuration = cooldownDuration_;
        }

        if(bidIncrement_ != 0) {
            _bidIncrement = bidIncrement_;
        }

        if(initialBaseCostPerPixel_ != 0) {
            _initialBaseCostPerPixel = initialBaseCostPerPixel_;
        }

    }

    /// @notice Permissionless function that can be called by anyone to close the current epoch
    function closeEpoch() external {
        require(_poolState == PoolState.ENDED, "RentPool: Pool must be ended!");
        require(block.timestamp > _endDate + 7 * 1 days, "RentPool: Pool can only be closed 7 days after end date");

        if(_pendingBlockReward > 0) {
            _blockReward += _pendingBlockReward;
        }
        if(_pendingPixelReward >0) {
            for(uint256 i=0; i<100;){
                _pixelReward[_pixelIds[i]] += _pendingPixelReward;
            }
        }

        _deleteEpochStates();
        _poolState = PoolState.DORMANT;

        

    }

    function activate(uint256 duration_) external {
        require(_poolState == PoolState.DORMANT, "RentPool: Pool must be dormant!");
        require(
            _stakedBlockContract.ownerOf(_blockId) == msg.sender /// Block already in pool, caller has stBlock
            ||
            _blockContract.ownerOf(_blockId) == msg.sender /// Caller is Block owner
            ,
            "RentPool: Block not found or not owned");

        require(duration_ <= 2, "RentPool: Duration out of bound!");

        _duration = _mapNumToDuration(duration_);
        _initialCostPerPixel = getInitialCostPerPixel(duration_);

        if (_blockContract.ownerOf(_blockId) == msg.sender){
            _blockContract.transferFrom(msg.sender, address(this), _blockId);
        }
    }

    function deactivate() external {
        require(_poolState == PoolState.ACTIVE, "RentPool: Pool must be active!");
        require(
            _stakedBlockContract.ownerOf(_blockId) == msg.sender /// Block already in pool, caller has stBlock
            ||
            _blockContract.ownerOf(_blockId) == msg.sender /// Caller is Block owner
            ,
            "RentPool: Block not found or not owned"
        );

        _poolState = PoolState.DORMANT;

    }

    /// @notice Permissionless function, called when cooldown period ends to initiate the rent epoch. 
    /// External caller will be rewarded with 0.5% of all bids.
    function initiate() external {
        require(_poolState == PoolState.PENDING && block.timestamp > _cooldownEndDate, "RentPool: Unable to initiate rent");
        
        if(!isFullyStaked()) {
            _poolState = PoolState.ACTIVE;

            /// Refund all bidders and set to active - epoch cancelled
            for(uint256 i = 1; i < _numBids + 1;){
                address bidder = _bidToBidder[i];
                uint256 lastBid = _bidderToLastBid[bidder];

                if(lastBid == i) {
                    uint256 bidCost = _bidCostPerPixel[i] * 100;
                    uint256 tax = bidCost * 5 / 1000; /// 0.5%
                    if (i==_numBids) {
                        tax = bidCost * 2 / 100; /// 2% penalty for not resolving winning bid
                    }
                    uint256 toBidder = bidCost - tax;
                    uint256 toCaller = tax;

                    payable(bidder).transfer(toBidder);
                    payable(msg.sender).transfer(toCaller);
                }

                unchecked{
                    i++;
                }
            }
            _deleteEpochStates();
        } else {

            uint24[] memory colors = _bidColors[_numBids];
            _origColors = _blockContract.getPixelColors(_blockId);
            _startDate = block.timestamp;
            uint256 numDays = (_duration==Duration.THIRTY) ? 30 : (_duration==Duration.NINETY) ? 90 : 180;
            _endDate = _startDate + numDays;

            uint256 epoch = _epoch++; /// start new epoch
            address tenant = _bidToBidder[_numBids];


            EpochMetadata memory metadata = EpochMetadata(epoch, _startDate, _endDate, _finalBidCostPerPixel, tenant, _duration);
            _epochs.push(metadata);
            _pixelContract.transform(colors, _pixelIds);
            
            _poolState = PoolState.ONGOING;

            // Refund all bidders except for last bidder
            for(uint256 i = 1; i < _numBids;){
                address bidder = _bidToBidder[i];
                uint256 lastBid = _bidderToLastBid[bidder];

                if(lastBid == i) {
                    uint256 bidCost = _bidCostPerPixel[i] * 100;
                    uint256 tax = bidCost * 5 / 1000; // 0.5%
                    uint256 toBidder = bidCost - tax;
                    uint256 toCaller = tax;

                    payable(bidder).transfer(toBidder);
                    payable(msg.sender).transfer(toCaller);
                }

                unchecked{
                    i++;
                }
            }
            
        }
    }

    /// @notice For caller to make their first bid in the rent epoch
    function makeBid(uint256 costPerPixel_, uint24[] memory colors_) external payable {
        require(_poolState == PoolState.ACTIVE || _poolState == PoolState.PENDING, "RentPool: Pool must be active or pending");


        require(costPerPixel_ >= getMinNextBidCost(), "RentPool: Bid should be higher!");

        require(msg.value >= costPerPixel_ * 100, "RentPool: Insufficient ETH balance");
        require(!isBidder(msg.sender),"RentPool: Caller already has bids");

        _storeBid(colors_, msg.sender, costPerPixel_);

        if(_poolState == PoolState.ACTIVE) {
            _poolState = PoolState.PENDING;
        
            /// Update epoch variables
            _cooldownStartDate = block.timestamp;
            _cooldownEndDate = _cooldownStartDate + _cooldownDuration * 1 days;
        }
    }

    /// @notice For caller with existing bid(s) to update their bid
    function updateBid(uint256 newCostPerPixel_, uint24[] memory colors_, bool isColorChanged) external payable {
        require(_poolState == PoolState.PENDING, "RentPool: Pool must be pending");
        require(newCostPerPixel_ == getMinNextBidCost(), "RentPool: Bid should be higher!");
        require(isBidder(msg.sender),"RentPool: Caller is not bidder");

        uint256 key = _bidderToLastBid[msg.sender];

        uint256 diffToTopUp = newCostPerPixel_ - _bidCostPerPixel[key];
        require(msg.value >= diffToTopUp * 100, "RentPool: Insufficient ETH balance");

        if(isColorChanged){
            _storeBid(colors_, msg.sender, newCostPerPixel_);
        }
        else {
            _storeBid(_bidColors[key], msg.sender, newCostPerPixel_);
        }
    }

    function _storeBid(uint24[] memory colors_, address bidder_, uint256 costPerPixel_ ) internal {
        /// @dev 1-based indexing so that
        /// the default value of zero in the _bidderToLastBid mapping indicates no bid from the user, 
        /// instead of the erroneous fact that the user made the first bid
        _numBids++; 
        _bidColors[_numBids] = colors_;
        _bidToBidder[_numBids] = bidder_;
        _bidderToLastBid[bidder_] = _numBids;
        _bidCostPerPixel[_numBids] = costPerPixel_;
        _finalBidCostPerPixel = costPerPixel_;
    }

    function isBidder(address account_) public view returns(bool) {
        return _bidderToLastBid[account_] != 0;
    }


    /// @notice Pixel owner stakes their pixels and in return, receives an stPIXEL (Staked Pixel) for each pixels staked 
    /// Staking is only allowed when the pool is Pending
    function stakePixel(uint256[] memory ids_) external {
        require(_poolState == PoolState.PENDING, "RentPool: Pool must be pending");
        uint256 numPixels = ids_.length;
        for(uint256 i = 0; i < numPixels;) {
            if(_pixelContract.getBlockId(ids_[i]) != _blockId) {
                revert("RentPool: Pixel does not belong to block");
            }
            if(_pixelContract.ownerOf(ids_[i]) != msg.sender) {
                revert("RentPool: Pixel not owned");
            }
            unchecked {
                i++;
            }
        }

        _pixelContract.transferFrom(msg.sender, address(this), ids_);
        
        _stakedPixelContract.mint(ids_, msg.sender);
        
    }

    /// @notice Pixel owner unstakes their pixels by sending the stPIXEL (Staled Pixel) equivalent to the contract, which will then be burned by the contract. In return, they receive back the pixels they staked in the contract
    function unstakePixelWithRewards(uint256[] memory ids_) external {
        require(_poolState != PoolState.PENDING || _poolState != PoolState.ONGOING, "RentPool: Pool must not be pending or ongoing");
        uint256 numPixels = ids_.length;

        for(uint256 i = 0; i < numPixels;) {
            if(_stakedPixelContract.ownerOf(ids_[i]) != msg.sender) {
                revert("RentPool: stPixel not owned");
            }
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
    /// Staking is only allowed when the pool is Pending
    function stakeBlock() external {
        require(_poolState == PoolState.PENDING, "RentPool: Pool must be pending");
        require(
            _blockContract.ownerOf(_blockId) == msg.sender // Caller is Block owner
            ,
            "RentPool: Block not owned"
        );

         _blockContract.transferFrom(msg.sender, address(this),_blockId);

        _stakedBlockContract.mint(_blockId, msg.sender);
        
    }

    /// @notice Block owner unstakes their block by sending the stBLOCK (Staked Blcok) equivalent to the contract, which will then be burned by the contract. In return, they receive back the block they staked in the contract
    function unstakeBlockWithRewards() external {
        require(_poolState != PoolState.PENDING || _poolState != PoolState.ONGOING, "RentPool: Pool must not be pending or ongoing");
        require(
            _stakedBlockContract.ownerOf(_blockId) == msg.sender // Caller is Block owner
            ,
            "RentPool: stBlock not owned"
        );

        uint256 reward = _blockReward;
        delete _blockReward;

        _stakedPixelContract.burn(_blockId);
        _blockContract.transferFrom(address(this),msg.sender,_blockId);

        payable(_msgSender()).transfer(reward);
        
    }

    function getInitialCostPerPixel(uint256 num_) public view returns(uint256) {
        if(num_>2) {
            return 0;
        }

        return _initialBaseCostPerPixel * (num_ + 1);
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

    function getMinNextBidCost() public view returns(uint256) {
        if(_numBids==0) return _initialCostPerPixel;
        return _bidCostPerPixel[_numBids - 1] * (100 + _bidIncrement) / 100;
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

    function _deleteEpochStates() internal {
        delete _initialCostPerPixel;
        delete _duration;
        delete _origColors;
        delete _finalBidCostPerPixel;
        delete _pendingBlockReward;
        delete _pendingPixelReward;
        delete _numBids;
        delete _cooldownStartDate;
        delete _cooldownEndDate;
        delete _startDate;
        delete _endDate;

        /// @dev Unable to delete mappings:
        /// _bidToBidder;
        /// _bidderToLastBid;
        /// _bidColors;
        /// _bidCostPerPixel;
        /// While mappings are not deleted, it does not matter as they are overridden and do not affect anything
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){}
    
} 