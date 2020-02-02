Smart Contract based Data Trading
-------------------------------------------

This is an implementation of data trading using multiple smart contracts to provide specific functionality in the marketplace as given below.

There are four smart contracts specifically designed to perform function as given below.

1) Register contract - It maintains the look up table for the data subscription contracts

2) Data subscription contract - It maintains the subscription list between a buyer and seller

![rating](https://user-images.githubusercontent.com/58245210/73608827-b69c9d80-461b-11ea-92f1-b0e404861ac2.png)

3) Pricing contract - It maintains the price index of different data types traded in the marketplace and calculates the data price.

![price](https://user-images.githubusercontent.com/58245210/73608892-4c382d00-461c-11ea-99fc-7e19ed013ab2.png)

4) Rating contract - It maintains the summary of the trading history between a seller and a buyer. It calculate the reputation score using the current transaction value and trading summary.

![regi](https://user-images.githubusercontent.com/58245210/73608890-49d5d300-461c-11ea-8ca4-8bc453e0c5e6.png)


Limitation: Fixed point numbers are not fully supported by Solidity. Therefore, the contracts are developed with Integer values.
            Similarly, exponential functions are also omitted in the implementation.


This is version 1.0, DataMart is still under development. The current prototype is just to demonstrate the interactions of the four smart contracts to achieve the data trading in an autonomous and automatic manner.
