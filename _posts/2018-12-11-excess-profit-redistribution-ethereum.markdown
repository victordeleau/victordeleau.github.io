---
layout: post
title:  "Excess profit redistribution using an Ethereum smart contract"
date:   2018-12-10 00:00:00 -0000
categories: post
---
Smart contract are a new software technology which are able to replace third-parties in a typical contractual situation. They are running in a decentralised manner on a blockchain   network, are almost autonomous, and are secured by modern cryptography like Bitcoin. The first blockchain platform to have implemented and mature them is Ethereum.

I - Introduction

II - Environment setup

III - Smart contract code

IV - Deployment

V - Testing



### Introduction

In this post I will go through the different phases of deployment of an Ethereum smart contract. We will use the Solidity language. Here is the plot of the smart contract we will try to deploy: Whenever a business wants to invest into something and make it available to his clients, he will choose a first conservative price which will increase the probability for him to get his investment back. Then, if the product is successful, the business will lower the price in order to attract even more client and maximize his profit. In such situation, the first client are losing because they are paying more than they should. To solve this situation, we will first choose a first conservative price for the business. Then we will create a smart contract which will gather every new payment. When the sum of the money gathered reach the ReturnOverInvestment event (ROI), the smart contract will send the specified amount to the business. Then the smart contract will continue to gather payment until a specified end date. The remaining fund will then be equally distributed to every client, such that they would have paid the same amount of money for the object or service associated.



### Environment setup

Now let's see how we could implement this idea. First we need to setup an Ethereum coding environment. In order to interact with the Ethereum network, we need to install an   Ethereum node. They are several node software available; here we will use Geth, a Go implementation which is well maintained by the community. A Geth node support three kinds of synchronisation which determines what you can do with them: full node, fast node and light node. I won't go into details about it but because we want to have a fast and easy access we will use a light node which can synchronise in less than a minute. Personally I am running one on a RaspberryPi server and connect myself to it using SSH. We will add the '--rinkeby' option which will connect us to a testnet instead of the mainnet: it allows us not to spend real and valuable Ether while testing.

    geth --syncmode 'light' --rinkeby console

We now have access to a javascript console known as JRSE [https://ethereum.gitbooks.io/frontier-guide/content/jsre.html]. We will use this console to interact with the Ethereum blockchain. Let's create an address and check it's current balance.

    > personal.newAccount('fairbusiness')
    '0x6eb9f04ae037808370f5e18870d2cfe89792abe4'
    > eth.accounts[0] '0x6eb9f04ae037808370f5e18870d2cfe89792abe4'
    > eth.getBalance(eth.accounts[0])
    0

Unless you are extremely lucky, your address will be empty so you need to get some Ether. On the Rinkeby testnet, you can either receive them from someone or use the [Rinkeby Faucet](https://faucet.rinkeby.io/), a web application which will verify that your are not an automated program through one of your social media profile. If you are not on a social media, send me a message with your address and I will send   you some. The returned string is our public address, which we can shared with others in order to receive Ether. The string specified in the newAccount field is our wallet password, which is encrypted on the node to create our private key. Smart contract code  Here is the smart contract source code written in Solidity. We can see that the syntax is close to javascript.

    /* A fair and efficient business using an Ethereum smart contract Original idea by Jia Yuan Yu, coded by Victor Deleau, last modification: 26/03/18 */

    pragma solidity ^0.4.21;

    contract fair {

    // Declare variables ///////////////////////////////////////////////////////

    /* Address of the business */
    address public business;

    /* This is the name of the object/service for which the client will pay */
    string public entity;

    /* The sc will end at this block height */
    uint public finalBlock;

    /* The price setup by the business for the object/service */
    uint public price;

    /* The amount of money required to fire the ROI event */
    uint public target;

    /* The amount of money redistributed, if ROI event happened */
    uint public redistributedFund;

    /* A boolean variable for the ROI event, True if ROI happened */
    bool public roi = false;

    /* create array of client addresses */
    address[] private addressIndex;


    // Declare modifiers and events ////////////////////////////////////////////

    /* A modifier acts as a filter on other functions */
    modifier onlyOwner() {require (business == msg.sender);_;}

    /* emit an event when a new transaction is received */
    event newTransactionEvent(address client,address business,string entity,uint price);

    /* emit an event when we reach the target */
    event roiEvent(address business, string entity);

    /* emit an event when the sc is killed or has ended */
    event killEvent(address business, string entity, uint redistributedFund);


    // Functions ///////////////////////////////////////////////////////////////

    /* Constructor of the sc when deployed, same name as contract */
    function fair(string _entity, uint _finalBlock, uint _price, uint _target)
        public {business = msg.sender;
        entity = _entity;
        finalBlock = _finalBlock;
        price = _price;
        target = _target;
        redistributedFund = 0;
    }

    /* Distribute all the fund to the clients */
    function distribute() private returns (uint) {

        // private because internal function
        uint nbClient = addressIndex.length;
        uint amount = address(this).balance / nbClient;
        for (uint i = 0; i < nbClient; i++) {
            addressIndex[i].transfer(amount);
        }
        return amount;
    }

    /* Check if the target is reached. If yes pay the business */
    function checkState() private returns (bool) {
        if ( roi == false ) {
            // this can only happen one time
            if ( address(this).balance > target ){
                roi = true; // set the roi variable
                statebusiness.transfer(target); // pay the business
                emit roiEvent(business, entity);
            }
        }
    }

    /* Check if the contract has ended or not */
    function checkTime() private view returns (bool) {
        if ( block.number > finalBlock ) { return true; }
    }

    /* A function to destroy the smart contract and distribute the funds */
    function kill() private {
        /* Distribute the fund to the clients before killing the sc */
        if (roi == true) { redistributedFund = distribute(); }

        /* Kill the sc */
        emit killEvent(business, entity, redistributedFund);
        selfdestruct(business);
    }

    /* If someone want to trigger a state checking from outside */
    function manualCheck() public {checkState();

        // check current state
        if ( checkTime() == true ) { kill(); }

    // if contract has ended}

    // Fallback function//////////////////////////////////////////////////////

    /* fallback function, which get called when a transaction has no data */
    function () payable public {
        if ( msg.value != price ) {
            revert(); // reject transaction if not equal to price
        }
        else { // else new transaction is successfull
            emit newTransactionEvent(msg.sender, business, entity, price);
            addressIndex.push(msg.sender);
        }
        checkState(); // check current state
        if ( checkTime() == true ) kill(); // if contract has ended
    }

    } // END



### Deployment

We first need to compile the source code into an ABI (Application Binary Interface, which allows us to interact with the smart contract) and a BIN file (the binary code which will be stored in the blockchain). For this matter we use [solc](http://solidity.readthedocs.io/en/v0.4.21/installing-solidity.html), the solidity compiler. I do not recommend the nodeJS implementation which is buggy, but rather to build it from source or to use the online compiler [remix](http://remix.ethereum.org/). Here is how to compile our source code using solc in the command line:

    solc --bin --abi fair.sol -o compil

We will get the output files in the local compil/ directory. Now we need to deploy the smart contract. There are several ways to do this, but here we are going to use the most basic and proven method using the geth console. First, we want to store the parameters of our smart contract and other usefull variables:

    > var entity = 'tourte';
    > var nb_day = 365;
    > var price = 0.1;
    > var target = 0.3;
    > var final_block_number = ( (nb_day * 3600) / 15 ) + eth.blockNumber;
    > var wei = 1000000000000000000;

Deploying a smart contract is nothing more than sending a transaction with some specific data included. We will build a transaction object piece by piece and then broadcast the transaction to the network. Manually store the content of the .bin file into a variable and create a contract object using the web3.eth.contract class with the content of the .abi file as parameter:

    > var bin = "0x606060......70029";
    > var abi = web3.eth.contract([{"constant":true,"inputs":[]........"type":"event"}]);

Create a new transaction object with the right Gas amount. Gas is a payment unit for miners in charge of processing your transaction. The Gas price is specified in wei (10**⁻18 Ether) and vary according to the network current state. When you want to make a transaction, you can specify your Gas price (in wei) and the maximum amount of Gas that you are willing to spend. Because miners are here to make profits, they will pick up in priority transactions with the highest Gas price. If your Gas price is too low, you take the risk that your transaction will never be mined. On the other side, if the maximum Gas amount that you allow to be used is to low for what you ask, your transaction will fail for running out of Gas, but you will still have to pay for the computation done by the miner. Here is how to estimate those parameters when you make a transaction:

    > var gas_price = web3.eth.gasPrice;
    > var transaction_object = { from: web3.eth.accounts[0], data: bin };
    > var cost = web3.eth.estimateGas(transactionObject);
    > var fee = gas_price * cost;
    > fee / wei
    0.000812873

So 0.000812873 Ether is the price we would have to pay in order to deploy our smart contract on the Ethereum blockchain. Not much right ? Also note that Gas not used by the miner will be returned to you. Because the size of the Ethereum blockchain is increasing exponentialy, Ethereum developers are thinking about creating a [storage fee](https://ambcrypto.com/ethereum-eths-creator-to-charge-a-fee-for-data-storage-developers-in-trouble/) to keep our data or smart contract stored into the blockchain. While this might not be a very popular proposition, it could be a long term benefit for Ethereum. Let's get back to the deployment of the smart contract. We can now update our transaction object, unlock our local wallet and then deploy the smart contract:

    > var transaction_object = { from: web3.eth.accounts[0], data: bin, gas: cost*1.1 };
    > personal.unlockAccount(eth.accounts[0], "fairbusiness")
    true
    > var fair = abi.new(    entity, finalBlockNumber, price*wei, target*wei,    transactionObject, function (e, contract){       console.log(e, contract, "Contract waiting to be mined ...");       if (typeof contract.address !== 'undefined') {            console.log('Contract mined! address: ' + contract.address            + ' transactionHash: ' + contract.transactionHash);    } })

We created a 'fair' smart contract object which contain every thing we need to communicate with our smart contract (which is not mined until specified). If you wait a minute or so, the callback function will inform you that your contract has been mined (or not). In case of success, the smart contract address will be stored inside the fair object:

    > fair.address
    "0xea93952b7a1b2a9e413cc31a981f30f9adef2e1c"
    > fair.entity()
    "tourte"

That's it, our contract is now on the Ethereum rinkeby blockchain, and the procedure is the same for the mainnet.



### Testing

Let's imagine that I am a client and I want to pay for the specified object or service (described by the 'entity' variable):

    > eth.sendTransaction({   from:eth.accounts[0],   to:fair.address,   value: web3.toWei(0.2, "ether") });
    > "0x6473673030f3b34112b85c406c83425be7a5fea126f5f4a62121f7cad0541717"
    We created a new transaction which will trigger the default function() of the smart contract. The string returned is the TX (transaction hash) of the transaction. It allows us to check the state of the transaction.
    > eth.getTransaction(   "0x6473673030f3b34112b85c406c83425be7a5fea126f5f4a62121f7cad0541717");
    {   blockHash: "0x1772c18aa68ae22f6df1f4bae3cc8d87164aa150425af3390d0f902f6716a3f0",   blockNumber: 2029215,   from: "0x75a47d8aea5b4029341960bc5e942826c934b297",   gas: 90000,   gasPrice: 2000000000,   hash: "0x6473673030f3b34112b85c406c83425be7a5fea126f5f4a62121f7cad0541717",   input: "0x",   nonce: 46,   r: "0x2ce0f72f633e65325010054e57afdde277ea3c200e3ce128c139f38ef9386d30",   s: "0x7ff7e52dd58d074c6372af25e3c13060ad32ed04c07e436df3d836e18a14201b",   to: "0xea93952b7a1b2a9e413cc31a981f30f9adef2e1c",   transactionIndex: 4,   v: "0x2b",   value: 200000000000000000 }

If you check the amount of ether you have on your address after a few minutes, you will see that it wasn't debited of the transaction of 0.2 Ether you just made. That is because the smart contract verified the amount of Ether received to see if it matched the price of the entity (which is of 0.1 ETH). Our transaction was therefore rejected ! We can also see that on a blockchain explorer
[https://rinkeby.etherscan.io/tx/0x6473673030f3b34112b85c406c83425be7a5fea126f5f4a62121f7cad0541717]
. If we make another transaction with the right price now:

    > eth.sendTransaction({   from:eth.accounts[0],   to:fair.address,   value: web3.toWei(fair.price(), "wei") });
    "0xe25f5d16c16a06155a2fbfe5a25f0a5c6db25917a74d85b155c8c1b7de510b11"

This time, we were indeed debited from the transaction amount. If we send three more transaction with the same amount of Ether, we will reach the target (0.3 ETH) and the smart contract will send us a payment for the ROI event, as specified in the source code, because we are the creator of the smart contract. While it hasn't been completely done here, it is extremely important to test a smart contract thoroughly. Huge amount of Ether were lost or stolen in the past because smart contract had flaws. Learning more by reading the [documentation](https://solidity.readthedocs.io/en/v0.4.21/), trying to consider every possible cases, and creating a complete test procedure to apply is heavily recommended.
