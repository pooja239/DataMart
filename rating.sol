// Rating contract is used to evaluate the reputation score of the actors based on their interactions with each other. Structure reputation contains the key 
// parameters based on actor's behviour and contract fulfillment creditbility. Instead of recording the entire trade history, we are using structure trade_summary
// to record the summary of the trade history between two actors. To avoid historical trade behaviour impacting current reputation score, we use a sliding window technique in
// recording the summary of trade. If the current time of trade is greater than the certain duration (lastrequestTime) then it will reset the trade summary parameters. 
// function recordSummary is used to record the trade summary and reset the summary based on the siding window. It also calls function updatescore to update the reputation
// score of the actor. Function dispute returns the most dishonest actors based on their reputation score or dishonest behaviour. getScore is used to get the score of
// any actor. Function penalty calculates the penalty for the dishonest actor.

pragma solidity >=0.4.22 <0.6.0;
contract Rating{
    
    struct reputation{
      uint ReputationScore; //reputation score of the actor
      uint contract_fail;   // number of failed contract
      uint contract_total; // total number of contract
      uint dishonest;      //dishonest behaviour of the actor
      bool initialized;    //check is the scores are initialized or not
    }
	
    struct trade_summary{
      uint ToLR; //time of last request
      uint f_p; //negative feedback
      uint f_t; //total number of feedbacks
      uint T_max; //maximum transaction valuel
      uint C_n; //number of collusive transactions since the ToLR
      uint length;
    }
	
	//this is initialized when deploying the ratnig contract. 

        uint base;
        uint interval;
        uint lastrequestTime;

    
    constructor(uint _base, uint _interval, uint _lastrequestTime ) {
        base = _base;
        interval = _interval;
        lastrequestTime = _lastrequestTime;
    }
    
    bytes32[] keyNames;										// key =(buyer,seller)
	
    mapping (address=> reputation) public Score;			// participants's reputation score
    mapping (bytes32=> trade_summary) public Summary;		//participant's trading summary
    
	
	//function is used to initialize the score of the participant
    function initializeScore(address _actor) public {
        reputation storage rep = Score[_actor];
        if (!rep.initialized) {
          rep.initialized = true;
          rep.ReputationScore = 5;
        }
    }
    
   function recordSummary(address _rater, address _receptor, uint _value, uint _feedback, uint _timestamp, uint _status) public 
    {
		//summary of trading history is identified by both the rater and receptor keys
        bytes32 key = keccak256(abi.encodePacked(_rater, _receptor));
        if (Summary[key].length == 0) {
            keyNames.push(key);
        }
		if (_status == 0) //When the contract is violated
        { 
		        _status=0;
		        _value=0;
		        _feedback=0;  
        }
        updatescore(_rater, _receptor, _status, _value, _feedback, Summary[key].length);
		
		//When the rater is trading first time with the receptor or
		//if the time to last request was while ago compared to lastrequestTime, reset the trade summary
		if ((_timestamp-Summary[key].ToLR >= lastrequestTime) || (Summary[key].length == 0)) 
		{		
            Summary[key].f_t = 1;
            Summary[key].T_max = _value;
            Summary[key].C_n = 1;
		    if (_status==1)
		    {
			    if(_feedback>=5){
			        Summary[key].f_p = 1;
				}
			    Summary[key].f_t= 1;
           }
		}
		else {
			    if (_status==1)
                {
                    if (_feedback>=5)
                    {
                        Summary[key].f_p = Summary[key].f_p+1;    ///update # of positive feedback
                    }
                    Summary[key].f_t = Summary[key].f_t+1;        ///update # of total feedback
                    if(_value>Summary[key].T_max)
                    {                
                        Summary[key].T_max = _value;              ///update max value
                    }
                    Summary[key].C_n = Summary[key].C_n+1;        //update # of collusive activity
                }
		}
		Summary[key].ToLR = _timestamp;       //update ToLR       
   }
    
    //To calculate the reputation score of the actor
    function updatescore(address _rater, address _receptor, uint _status, uint _value, uint _feedback, uint _length) public {
		bytes32 key = keccak256(abi.encodePacked(_rater, _receptor));
		uint RS;
		uint raterScore = Score[_rater].ReputationScore;
		uint receptorScore = Score[_receptor].ReputationScore;
		//if the transaction between buyer and seller is first time
        if (_length == 0) {
			if (_status==0) {		// if the contract was violated then it reduce the score to half
			    RS = receptorScore/2;
			    Score[_receptor].contract_fail = Score[_receptor].contract_fail+1; //increase number of the failed contract
			}
			else
			{
			    if(_feedback>=5){	//if the feedback is positive
			        RS = 9*receptorScore+_feedback;
			    }
			     else{	//if the feedback is negative
			        RS = (receptorScore+_feedback)/2;
			    }
			}
       }
       else {		//if the transaction is not first time
            if (_status==1)
            {
                uint tuning = (((raterScore)/(raterScore+receptorScore)*(Summary[key].f_p/Summary[key].f_t))+(_value/Summary[key].T_max))/(Summary[key].C_n*Summary[key].C_n);
                RS = (10-tuning)*(receptorScore)+tuning*_feedback;
			}
            else {
                RS = receptorScore/2;
			    Score[_receptor].contract_fail = Score[_receptor].contract_fail+1;
            }
		}
		Score[_receptor].contract_total = Score[_receptor].contract_total+1;
		Score[_receptor].ReputationScore = RS/10;
    }
	
	//Get the reputation score of the actor
    function getScore(address _receptor) public view returns (uint) {
        return Score[_receptor].ReputationScore;
    }
    
	//find out which actor behaved dishonestly based on the reputation score
	function Dispute(address actor1, address actor2) public returns(address) {
        address actor;
        if(getScore(actor1)>getScore(actor2)){	//actor 2 is dishonest
            Score[actor2].dishonest = Score[actor2].dishonest+1 ;
            actor = actor2;
        }
        if(getScore(actor1)<getScore(actor2)){	//actor 1 is dishonest
            Score[actor1].dishonest++;
            actor =  actor1;
        }
        if(getScore(actor1)==getScore(actor2)){ //both actors score are equal
            if (Score[actor1].dishonest > Score[actor2].dishonest)		//which actor behave dishonestly more number of times.
                {actor = actor1;}
            else
                {actor = actor2;}
        }
        return actor;
    }
    
	///calclate the actor penalty
    function penalty(address actor) public view returns(uint) {
        uint base = 10;
        uint interval = 1;
        return base**(Score[actor].dishonest/interval);
    }   
}
