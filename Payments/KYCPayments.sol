pragma solidity ^0.8.9;
//SPDX-License-Identifier: MIT

// -------------------------------------------------------------------------------------------------------
// kys.systems                                                                              Payment module
//
//
//
//
// UI:
// - [Admin] Create new bill      =====>  createBill([address] user, [uint] amount, [string] billId)
// - [Admin] Change billed amount =====>  changeBilledAmount([address] user, [string] billId, [uint] amount)
// - Read billed amount           =====>  readBilledAmount([address] user, [string] billId)
// - Charge for "no interview"    =====>  generalPayments([uint8] 0)
// - Charge for "with interview"  =====>  generalPayments([uint8] 2)
// - Charge for custom offer      =====>  customPayments([uint] billId)
//
// -------------------------------------------------------------------------------------------------------
//
// For custom offer user has to give us his address beforehand
// Flow:
//  1. Create bill for address with amount, bill id
//  2. User calls function from known address, provides bill id
//  3. Pays
//
// How to charge users:
//  1. Approve user spending allowance on USDT contract
//      - Call "approve" on USDT contract 
//      - spender => this contract
//      - amount => price/amount from bill
//  2. Call either generalPayments or customPayments
//
// -------------------------------------------------------------------------------------------------------

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "./interfaces/IERC20.sol";

contract KYCPayments is Ownable {

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- DECLARATIONS
    // -------------------------------------------------------------------------------------------------------

    // @notice                  bill keeps track of custom prices
    struct                      Bill {
      mapping(string => uint)   amountBilled;
      mapping(string => bool)   idUsed;
    }

    // @dev                     nested mapping address => (string => int)
    mapping(address => Bill)    dbBills;

    // @notice                  USDT token address via interface
    IERC20 public               USDT;

    // @notice                  an array of prices for services
    //                          0 — Owner no interview
    //                          1 - Owner with interview 
    uint256[] public            prices;




    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- EVENTS
    // -------------------------------------------------------------------------------------------------------

    // @param                   [address] user => user completed a payment
    // @param                   [uint256] amount => payment amount
    // @param                   [uint8] _type => service option
    //                                          0 — Owner no interview
    //                                          1 - Owner with interview 
    //                                          3 - Custom offer
    // @param                   [string] billId => bill id
    // @dev                     billId returns "none" for predefined payments (first 2 types)
    event                       PaymentCompleted(address indexed user, uint256 amount, uint8 _type, string billId);





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
    // ------------------------------- FIN CONTROL
    // -------------------------------------------------------------------------------------------------------

    // @notice                  allows to modify the price
    // @param                   [uint8] _priceToChange => offer index in the prices array:
    //                                                     0 — Owner no interview
    //                                                     1 - Owner with interview 
    // @param                   [uint256] _newPrice => new price
    function                    changePrice(uint8 _priceToChange, uint256 _newPrice) external onlyOwner {
        require(_priceToChange == 0 || _priceToChange == 1, "Incorrect option!");
        require(_newPrice > 0, "New price can't be zero!");
        prices[_priceToChange] = _newPrice;
    }

    // @notice                  function to return contract's USDT balance
    function                    readBalance() view external onlyOwner returns(uint256) {
        return(USDT.balanceOf(address(this)));
    }

    // @notice                  withdraws contract balance to specified address
    // @param                   [uint256] _newPrice => new price
    function                    withdrawBalance(address _to) external onlyOwner {
        require(_to != address(0), "Address can't be zero!");
        require(USDT.transfer(_to, USDT.balanceOf(address(this))) == true, "Failed to transfer USDT!");
    }




    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- CUSTOM OFFERS
    // -------------------------------------------------------------------------------------------------------

    // @notice                  restricts reading billed info only to address owner & owner
    modifier                    onlyAuthorized(address _addr) {
        require(msg.sender == _addr || msg.sender == owner(), "Not authorized!");
        _;
    }

    // @notice                  creates a new bill for user
    // @param                   [address] _addr => user billed
    // @param                   [uint256] _amount => billed amount
    // @param                   [string] _billId => bill id
    function                    createBill(address _addr, uint256 _amount, string memory _billId) external onlyOwner {
        require(dbBills[_addr].idUsed[_billId], "Bill id is not available!");
        dbBills[_addr].amountBilled[_billId] = _amount;
        dbBills[_addr].idUsed[_billId] = true;
    }

    // @notice                  billed amount getter
    // @param                   [address] _addr => user billed
    // @param                   [string] _billId => bill id
    function                    readBilledAmount(address _addr, string memory _billId) external view onlyAuthorized(_addr) returns(uint256) {
      return(dbBills[_addr].amountBilled[_billId]);
    }

    // @notice                  billed amount setter
    // @param                   [address] _addr => user billed
    // @param                   [string] _billId => bill id
    // @param                   [uint256] _new_amount => new bill amount
    function                    changeBilledAmount(address _addr, string memory _billId, uint256 _new_amount) external onlyOwner {
        dbBills[_addr].amountBilled[_billId] = _new_amount;
    }





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- PAYMENTS
    // -------------------------------------------------------------------------------------------------------

    // @notice                  predefined payment
    // @param                   [uint8] _offerChoice => offer index in the prices array:
    //                                                  0 — Owner no interview
    //                                                  1 - Owner with interview 
    function                    generalPayments(uint8 _offerChoice) external {
        require(_offerChoice == 0 || _offerChoice == 1, "Incorrect option!");
        require(USDT.allowance(msg.sender, address(this)) >= prices[_offerChoice],
                      "Not enough allowance, approve your USDT first!");
        require(USDT.balanceOf(msg.sender) >= prices[_offerChoice], 
                      "Not enough USDT!");
        require(USDT.transferFrom(msg.sender, 
                                  address(this), 
                                  prices[_offerChoice]) == true, 
                                  "Failed to transfer USDT!");
        emit PaymentCompleted(msg.sender, prices[_offerChoice], _offerChoice, "none");
    }

    // @notice                  payment via bill
    // @param                   [string] _billId => bill id
    function                    customPayments(string memory _billId) external {
      uint256                   amount;

      amount = dbBills[msg.sender].amountBilled[_billId];
      require(amount > 0, "Invalid bill!");
      require(USDT.allowance(msg.sender, address(this)) >= amount,
                      "Not enough allowance, approve your USDT first!");
      require(USDT.balanceOf(msg.sender) >= amount, 
                      "Not enough USDT!");
      require(USDT.transferFrom(msg.sender, 
                                address(this), 
                                amount) == true, 
                                "Failed to transfer USDT!");
      emit PaymentCompleted(msg.sender, amount, 2, _billId);
    }





    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- MISC
    // -------------------------------------------------------------------------------------------------------

    // @notice                  disable renounceOwnership
    function                    renounceOwnership() public pure override {
        require(false, "This function is disabled");
    }
}