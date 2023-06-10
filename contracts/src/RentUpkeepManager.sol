// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentFactory.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";


struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    bytes checkData;
    bytes offchainConfig;
    uint96 amount;
}

struct UpkeepInfo {
  address target;
  uint32 executeGas;
  bytes checkData;
  uint96 balance;
  address admin;
  uint64 maxValidBlocknumber;
  uint32 lastPerformBlockNumber;
  uint96 amountSpent;
  bool paused;
  bytes offchainConfig;
}

/// @title A simulator for trees
/// @author Larry A. Gardner
/// @notice You can use this contract for only the most basic simulation
/// @dev All function calls are currently implemented without side effects
interface KeeperRegistrarInterface {
    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);
}

interface AutomationRegistryBaseInterface {
    function addFunds(uint256 id, uint96 amount) external;
    function getUpkeep(uint256 id) external view returns (UpkeepInfo memory upkeepInfo);
}

contract RentUpkeepManager is Ownable {
    
    LinkTokenInterface private constant _link = LinkTokenInterface(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    KeeperRegistrarInterface private constant _registrar = KeeperRegistrarInterface(0x57A4a13b35d25EE78e084168aBaC5ad360252467);
    AutomationRegistryBaseInterface private constant _registry = AutomationRegistryBaseInterface(0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2);
    RentFactory private _rentFactory;
    bool private _rentFactoryIsSet;

    constructor() {
        _link.approve(address(_registrar), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }

    function addKeeper(address contract_) external returns(uint256 upkeepId) {
        require(msg.sender==address(_rentFactory), "RentUpkeepManager: Not the factory");
        
        RegistrationParams memory params = RegistrationParams(
            "upkeep",
            "0x",
            contract_,
            1000000, /// gas limit
            address(this),
            "0x",
            "0x",
            5e17
        );

        upkeepId = _registrar.registerUpkeep(params);
        if (upkeepId == 0) {
            revert("auto-approve disabled");
        }
    }

    function topUp(uint256 upkeepId_) external {

        UpkeepInfo memory upkeepInfo = _registry.getUpkeep(upkeepId_);

        if(upkeepInfo.balance >= 5e17) {
            /// only tops up when LINK balance < 0.5 LINK
            revert("RentUpkeepManager: Upkeep does not require funding");
        }
        _registry.addFunds(upkeepId_, 5e17);
    }

    function viewUpkeep(uint256 upkeepId_) external view returns (UpkeepInfo memory upkeepInfo) {
        upkeepInfo = _registry.getUpkeep(upkeepId_);
    }

    function attachFactory(address factoryContract_) public onlyOwner {
        require(!_rentFactoryIsSet, "RentUpkeepManager: Factory exists");
        _rentFactory = RentFactory(factoryContract_);
        _rentFactoryIsSet = true;
    }
}
