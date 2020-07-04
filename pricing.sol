//Implementation of the pricing contract is given below. The code presents the high-level implmentation of the contract. Price of the traded data 
// on the marketplace are recorded in pricingHistory which is based on the price structure. function record_priceindex records the price index for 
// each data type. getPrice fetches the average of the price based on the competitors price for a certain duration. In this we have assumed it to be
// 24 hrs. CalPrice calculates the price based on the quality score, risk score and negotiation rate.

pragma solidity >=0.4.22 <0.6.0;

contract Pricing{
    struct price{
        uint timestamp;
        uint price_index; //price index of the data.
    }

    string[] datatypes;
    
	mapping (string=> price[]) pricingHistory;
    
	/*record the data price*/
    function record_priceindex(string memory _datatype, uint _timestamp, uint _price, uint QS, uint RS) public {
        if (pricingHistory[_datatype].length == 0) {
          datatypes.push(_datatype);
        }
        uint new_PI = (100*_price)/(QS+RS+100);			//calcuate the price index of data type
        pricingHistory[_datatype].push(price(_timestamp, new_PI));	//record the price index and timestamp
    }
	
    function getPrice(string memory _datatype) public view returns (uint) {
		price[] memory priceInfo = pricingHistory[_datatype];
        uint historylen = priceInfo.length;
        uint N = 0;
        uint P = 0;
		uint duration = 24; //hrs
		//calculate the average of price index of N transactions taken place in "duration" time to get the base price
		for (uint i = historylen-1; i>=0; i--){
			if(priceInfo[i].timestamp>=duration){
                P = P+priceInfo[i].price_index;
                N = N+1;
            }
            else{
                break;
            }
            if(i==0){
                break;
            }
        }
        return P/N; //base price
    }
    
	///calcuate the price of the data using base price
	function CalPrice(string memory data_type, uint QS, uint RS, uint NR, uint SI, uint dur, uint time) public returns (uint){
        //get the base price and calculate the price of the 
		uint unit_price = (getPrice(data_type)*(100+QS+RS))/100;
        uint data_price = (unit_price*(100+NR)*dur)/(100*SI);
        record_priceindex(data_type, time, unit_price, QS, RS); //record the data price index in the BC
        return data_price;
    }
}
