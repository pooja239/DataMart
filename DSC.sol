// Implementation of the data subscription contract is given below. The code presents the high-level implmentation of the DSC to automatically
// execute different stages in the data trading using smart contracts. There are five steps involved which are executed in sequential manner to
// achieve the trading. The subscription stages are  Add, start, settlement, delete. Based on the off-chain notification, a transaction is issued to
// run different ABIs. The subscription moves to next stage when it has already completed the previous step. The contract maintains the
// subscription information of all the subscriptions agreement made between a buyer and seller in a table "subscriptionTable". Each subscription is identified a unique identifier "_subId"


pragma solidity >=0.4.22 <0.6.0;

import "./rating.sol";
import "./pricing.sol";
import "./Account.sol";

contract DSC{
    
    //manages the workflow of the agreement
    enum StatusChoices {Add, Active, Settlement, End, Abort} //used to control the workflow of the agreement
    
    
    struct subscriptionStruct{                  
        address seller;                         //the seller of the corresponding seller-buyer pair of the DSC;
        address buyer;                          //the buyer of the corresponding seller-buyer pair of the DSC;
        bytes32 Deviceid;                       //device assigned for demand;
        string datatype;                        //data type requested by buyer
        uint start_time;                        //start time of the subscription
        uint SI;                                //sampling interval of the data
        uint duration;                          //duration of the subscription
        uint payment_granularity;               //payment granularity
        StatusChoices stage;                    //stage of the subscription
        uint total_price;                       //total price of the subcription
        uint negotiation_rate;                  //negotiated terms
        bool exists;
    }
    
    uint[] subList;                             //maintains the list of subscription IDs
    Rating  rate;
    Pricing price;
    Account account;

    mapping (uint=> subscriptionStruct) subscriptionTable;

    event SubscriptionAdded(uint);
    event SubscriptionStarted(uint);
    event SubscriptionError(uint, string);
    event SubscriptionSettlment(bool);
    
    constructor(address _account, address _rate, address _price) {
        account = Account(_account);
        rate = Rating(_rate);
        price = Pricing(_price);
    }
    
    //add the subscription detail in the ledger
    function subscriptionAdd(uint _subId, string memory _deviceSN, string memory _datatype, uint _starttime, uint _SI, uint _dur, uint _QS, uint _RS, uint _PG, uint _NR, uint _timestamp) private{
        //uint _subId = subList.length; 
        subList.push(_subId);
        subscriptionTable[_subId].Deviceid = keccak256(abi.encodePacked(_deviceSN));
        subscriptionTable[_subId].datatype = _datatype;
        subscriptionTable[_subId].start_time = _starttime;
        subscriptionTable[_subId].SI = _SI;
        subscriptionTable[_subId].duration = _dur;
        subscriptionTable[_subId].payment_granularity = _PG;
        uint a = price.CalPrice(_datatype, _QS, _RS, _NR, _SI, _dur, _timestamp );
        subscriptionTable[_subId].total_price = a;
        subscriptionTable[_subId].negotiation_rate = _NR;
        subscriptionTable[_subId].exists = true;
        subscriptionTable[_subId].stage = StatusChoices.Add;
        //held 2*total_price money from both the seller and buyer account in the Smart contract
        emit SubscriptionAdded(_subId);
    }
    
    //this function sets the subscription state to active
    function SubscriptionStart(uint _subId, uint _time) private {
        require(uint(subscriptionTable[_subId].stage) == 0);
         if (_time == subscriptionTable[_subId].start_time) {
            subscriptionTable[_subId].stage = StatusChoices.Active;
            emit SubscriptionStarted(_subId);
         }
         else{
             emit SubscriptionError(_subId, "Not the start time");
         }
     }

    //this function returns the subscription detail
    function subscriptionInfo(uint _subId) private view returns (bytes32, string memory, uint, uint, uint, uint, uint) {
        require(subscriptionTable[_subId].exists, "Subscription does not exist.");
        return (
            subscriptionTable[_subId].Deviceid,
            subscriptionTable[_subId].datatype,
            subscriptionTable[_subId].start_time,
            subscriptionTable[_subId].SI,
            subscriptionTable[_subId].duration,
            subscriptionTable[_subId].payment_granularity,
            subscriptionTable[_subId].total_price
            //subscriptionTable[_subId].stage
            );
        //return uint(subscriptionTable[_subId].stage);
    }
    
    //this function performs the settlement between the actors
    function subscriptionSettlement(uint sellerCount, uint buyerCount, address seller, address buyer, uint _subId, uint _time, uint _fsb, uint _fbs) public payable {
        //require (msg.sender == seller && msg.sender == buyer);
        bool success = false;
        subscriptionTable[_subId].stage = StatusChoices.Settlement; 
        
        //Calculate the payment based on the payment granularity
        uint pay = subscriptionTable[_subId].total_price*subscriptionTable[_subId].payment_granularity*subscriptionTable[_subId].SI/subscriptionTable[_subId].duration;
        
        //Check if there is any conflict or not by comparing the counts sent by buyer and seller
        if(sellerCount != buyerCount){                              //conflict situation
            address disonestActor = rate.Dispute(seller,buyer);     //determine the dishonest actor based on the rating
            uint fine = rate.penalty(disonestActor);                //evaluate the penalty
            if (seller == disonestActor){                           //if seller is a dishonest actor, he will loose money
                success = account.transfer(buyer,seller,pay-fine);  
            }
            else{
                success = account.transfer(buyer,seller,pay+fine);  //if buyer is a dishonest actor
            }
        }
        else {
            success = account.transfer(buyer,seller,pay);           //if its a fair situation, make the payment
        }
        ///subscription stage changes
        if (_time < subscriptionTable[_subId].start_time+subscriptionTable[_subId].duration){       //if the current time is less than the subscription duration
               subscriptionTable[_subId].stage = StatusChoices.Active;                              // subscription needs to continue
        }
        else if (_time >= subscriptionTable[_subId].start_time+subscriptionTable[_subId].duration){ //if current time is greater than the duration time
            subscriptionTable[_subId].stage = StatusChoices.End;                                    // end the subscription
            rate.recordTrade(seller, buyer, subscriptionTable[_subId].total_price, _fsb, _time, 1); // record the feedback of the actors
            rate.recordTrade(buyer, seller, subscriptionTable[_subId].total_price, _fbs, _time, 1); // record the feedback of the actors
        }
        emit SubscriptionSettlment(success); // return true if the settlement is done, for unsuccessful settlement facilitator will get involved
        
    }
    
    function Delete() private {
        uint i;
        for (i; i<subList.length;i++){
            if(subscriptionTable[i].stage != StatusChoices.End) {
                break;
            }
        }
        if (i==subList.length){
            selfdestruct(msg.sender);
        }
    }
   
