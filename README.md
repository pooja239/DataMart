Smart Contract based Data Trading
-------------------------------------------

This is an implementation of data trading using multiple smart contracts to provide specific functionality in the marketplace as given below.

There are four smart contracts specifically designed to perform function as given below.

1) Register contract - It maintains the look up table for the data subscription contracts

2) Data subscription contract - It maintains the subscription list between a buyer and seller

3) Pricing contract - It maintains the price index of different data types traded in the marketplace and calculates the data price.

4) Rating contract - It maintains the summary of the trading history between a seller and a buyer. It calculate the reputation score using the current transaction value and trading summary.


Limitation: Fixed point numbers are not fully supported by Solidity. Therefore, the contracts are developed with Integer values.
            Similarly, exponential functions are also omitted in the implementation.


This is version 1.0, DataMart is still under development. The current prototype is just to demonstrate the interactions of the four smart contracts to achieve the data trading in an autonomous and automatic manner.
