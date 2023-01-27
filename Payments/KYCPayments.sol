// TODO:
// - Use access controll
// - Approve USDT
// - General payments
// - Custom payments
// - Price setters
// - Withdraw USDT to wallet

pragma solidity ^0.8.9;
//SPDX-License-Identifier: MIT

// For custom subscription user has to give us his addr beforehand
// Flow:
//  1. Create bill for address with amount, bill id
//  2. User calls function from known address, provides bill id
//  3. Retrieves amount for this bill

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "./interfaces/IERC20.sol";

contract KYCPayments is Ownable {

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- DECLARATIONS
    // -------------------------------------------------------------------------------------------------------

    // @notice                  bill structure keeps track of custom prices
    struct                      Bill {
    uint256                     amount;
    string                      billId;
    }
    mapping(address=>Bill[])    dbBills;
    mapping(string=>address)    usedIds;

    // @notice                  USDT token address via interface
    IERC20  public              USDT;

    // @notice                  an array of prices for services
    //                          0 — Owner no interview
    //                          1 - Owner with interview 
    uint256[] public            prices;





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- CONSTRUCTOR
    // -------------------------------------------------------------------------------------------------------

    // @param                   [address] _usdt => usdt contract address
    // @param                   [uint256] _price1 => price for 1st offer
    // @param                   [uint256] _price2 => price for 2nd offer
    constructor(address _usdt, uint256 _price1, uint256 _price2) {
        USDT = IERC20(_usdt);
        prices.push(_price1);
        prices.push(_price2);
        _transferOwnership(msg.sender);
    }





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- CUSTOM OFFERS
    // -------------------------------------------------------------------------------------------------------

    // @notice                  restricts reading billed info only to authorized users
    modifier                    onlyAuthorized(address _addr) {
        require(msg.sender == _addr || msg.sender == owner(), "Not authorized!");
        _;
    }

    // @notice                  checks if billId from storage is equal to provided one
    // @param                   [string] _dbbillId => storage billId
    // @param                   [string] _billId => provided billId
    function isEqual(string memory _dbBillId, string memory _billId) private pure returns(bool) {
        return keccak256(abi.encodePacked(_dbBillId)) == keccak256(abi.encodePacked(_billId));
    }

    // @notice                  creates a new bill for user
    // @param                   [address] _addr => user billed
    // @param                   [uint256] _price => billed ammount
    // @param                   [uint256] _billId => bill id
    function createBill(address _addr, uint256 _price, string memory _billId) external onlyOwner {
        Bill memory             new_bill;

        require(usedIds[_billId] != _addr, "billId is not available!");
        usedIds[_billId] = _addr;
        new_bill.amount = _price;
        new_bill.billId = _billId;
        dbBills[_addr].push(new_bill);
    }

    // @notice                  billed ammount getter
    // @param                   [address] _addr => user billed
    // @param                   [uint256] _billId => bill id
    function readBilledAmmount(address _addr, string memory _billId) external view onlyAuthorized(_addr) returns(uint256) {
        uint32                  i;

        while(isEqual(dbBills[_addr][i].billId, _billId) == false) {
            i++;
        }
        return (dbBills[_addr][i].amount);
    }

    // @notice                  billed ammount setter
    // @param                   [address] _addr => user billed
    // @param                   [uint256] _billId => bill id
    function changeBilledAmmount(address _addr, string memory _billId) external view onlyOwner returns(uint256) {
        uint32                  i;

        while(isEqual(dbBills[_addr][i].billId, _billId) == false) {
            i++;
        }
        return (dbBills[_addr][i].amount);
    }
}
