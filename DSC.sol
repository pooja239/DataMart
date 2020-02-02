// Implementation of the data subscription contract is given below. The code presents the high-level implmentation of the DSC to automatically
// execute different stages in the data trading using smart contracts. There are five steps involved which are executed in sequential manner to
// achieve the rading. The subscription stages are  Add, start, settlement, delete. Based on the off-chain notification, a transaction is issued to
// run different ABIs. The subscription moves to next stage when it has already completed the previous step. The contract maintains the
// subscription information of all the subscriptions agreement made between a buyer and seller in a table "subscriptionTable". Each subscription is identified a unique identifier "_subId"


pragma solidity >=0.4.22 <0.6.0;

import "./rating.sol";
import "./pricing.sol";
import "./Account.sol";

contract DSC{
    
    enum StatusChoices {Add, Running, Settlement, End, Abort} //used to control the execution flow of the agreement
    
    struct subscriptionStruct{
        uint subId; //subscription id
        bytes32 Deviceid; //device assigned for demand;
        string datatype; //data type requested by buyer
        uint start_time; //start time of the subscription
        uint SI; //sampling interval of the data
        uint duration; //duration of the subscription
        uint payment_granularity; //payment granularity
        StatusChoices stage; //stage of the subscription
        uint total_price; //total price of the subcription
        uint negotiation_rate; //negotiated terms
    }

	uint[] subList; //maintanis the list of all the subscriptions
    Rating public rate; //handler for rating contract
    Pricing public price; //handler for price contract
    Account public account; //handler for account contract

	//This is used for the initialization of all the other contracts addresses
    function set_contract(address _account, address _rate, address _price) public {
        account = Account(_account);
        rate = Rating(_rate);
        price = Pricing(_price);
       
    }

    mapping (uint=> subscriptionStruct) subscriptionTable;
	
	//This function is used to add the subscription information in the subscription list
    function subscriptionAdd(uint _subId, string memory _deviceSN, string memory _datatype, uint _starttime, uint _SI, uint _dur, uint _QS, uint _RS, uint _PG, uint _NR, uint _timestamp) public{
        subList.push(_subId);
        subscriptionTable[_subId].Deviceid = keccak256(abi.encodePacked(_deviceSN));
        subscriptionTable[_subId].datatype = _datatype;
        subscriptionTable[_subId].start_time = _starttime;
        subscriptionTable[_subId].SI = _SI;
        subscriptionTable[_subId].duration = _dur;
        subscriptionTable[_subId].payment_granularity = _PG;
		
		//price contract is used to calculate the price of the subscription based on the buyer's requirements
        subscriptionTable[_subId].total_price = price.CalPrice(_datatype, _QS, _RS, _NR, _SI, _dur, _timestamp );
        subscriptionTable[_subId].negotiation_rate = _NR;
        subscriptionTable[_subId].stage = StatusChoices.Add;
    }
    
	//This function is used to start the subsctiption
    function SubscriptionStart(uint _subId, uint _time) public {
         require(uint(subscriptionTable[_subId].stage) == 0);
         if (_time == subscriptionTable[_subId].start_time) {
            subscriptionTable[_subId].stage = StatusChoices.Running;
         }
         else{
             //Starting subscription at different time than start time.
         }
    }

	//To fetch the subsctiption info from the blockchain
    function subscriptionInfo(uint _subId) public view returns (bytes32, string memory, uint, uint, uint, uint, uint) {
        require(uint(subscriptionTable[_subId].stage) == 0);
        return (
            subscriptionTable[_subId].Deviceid,
            subscriptionTable[_subId].datatype,
            subscriptionTable[_subId].start_time,
            subscriptionTable[_subId].SI,
            subscriptionTable[_subId].duration,
            subscriptionTable[_subId].payment_granularity,
            subscriptionTable[_subId].total_price
            uint(subscriptionTable[_subId].stage)
            );
    }
    
	//This ABI is required to be send by both buyer and seller. The payment needs to be release based on the payment granularity. If its the end of the subscription, both participants are required to submit their feedback. 
    function subscriptionSettlement(uint sellerCount, uint buyerCount, address seller, address buyer, uint _subId, uint _time, uint _fsb, uint _fbs) public payable returns(bool){
        require (msg.sender == seller && msg.sender == buyer);
        bool success = false;
        subscriptionTable[_subId].stage = StatusChoices.Settlement; 
        // Based on the payment granularity, the payment is calculated
		uint pay = subscriptionTable[_subId].total_price*subscriptionTable[_subId].payment_granularity*subscriptionTable[_subId].SI/subscriptionTable[_subId].duration;
		//If dispute occurs
        if(sellerCount != buyerCount){
            address disonestActor = rate.Dispute(seller,buyer); //identify the dishonest actor based on the repution score
            uint fine = rate.penalty(disonestActor);			//penatly is calcualted
            if (seller == disonestActor){
                success = account.transfer(buyer,seller,pay-fine);
            }
            else{
                success = account.transfer(buyer,seller,pay+fine);
            }
        }
        else {
            success = account.transfer(buyer,seller,pay);		//transfer funds from buyer to seller
        }
        //if the subscrition is not ended then the status of the subcription remains "Running"
        if (_time < subscriptionTable[_subId].start_time+subscriptionTable[_subId].duration){
               subscriptionTable[_subId].stage = StatusChoices.Running;
        }
        else if (_time >= subscriptionTable[_subId].start_time+subscriptionTable[_subId].duration){ //if the duration of the subscription is over
            subscriptionTable[_subId].stage = StatusChoices.End; //subcription has ended
            rate.recordTrade(seller, buyer, subscriptionTable[_subId].total_price, _fsb, _time, 1);	//update the reputation score of selelr
            rate.recordTrade(buyer, seller, subscriptionTable[_subId].total_price, _fbs, _time, 1)	//update the reputation score of buyer
			//release the invoice to the buyer
        }
        return success;   
    }
    
	// Once subscription is over, it can be deleted from the list. If all the subscriptions are over between a buyer and seller, 
	// the DSC can be removed using self-destructt
    function subscriptionDelete() public {
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
}
