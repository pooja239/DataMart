pragma solidity >=0.4.22 <0.6.0;

import "./datasubscription.sol";

contract Register{
    
	struct contractStruct{
        address seller; //the seller of the corresponding seller-buyer pair of the DSC;
        address buyer; //the buyer of the corresponding seller-buyer pair of the DSC;
        address scAddress; //the address of the contract.
    }
	
    mapping (bytes32=> contractStruct) public lookupTable;

    /*register a data subscription contract (DSC)*/
    function contractCreate(string memory _scname, address _seller, address _buyer, address _scAddress) public {
        require (msg.sender == _seller && msg.sender == _buyer);
        bytes32 newKey = keccak256(abi.encodePacked(_scname));
        lookupTable[newKey].seller = _seller;
        lookupTable[newKey].buyer = _buyer;
        lookupTable[newKey].scAddress = _scAddress;
    }
    
	//remove the contract from the look up
    function contractRemove(string memory _contractName) public{
        delete lookupTable[keccak256(abi.encodePacked(_contractName))];
        
    }
    
    function contractGet(string memory _contractName) public view returns (address){
        bytes32 key = keccak256(abi.encodePacked(_contractName));
        return (lookupTable[key].scAddress);
    }
    
    function contractDelete(string memory _contractName) public{
        bytes32 key = keccak256(abi.encodePacked(_contractName));
        require (msg.sender == lookupTable[key].seller || msg.sender == lookupTable[key].buyer);
        DSC DSC1 = DSC(lookupTable[key].scAddress);
        DSC1.Delete(msg.sender);
        contractRemove(_contractName);
        
    }
}
