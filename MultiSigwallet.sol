//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract MultiSigWallet {

    address mainOwner;
    address[] walletOwners;
    uint limit;
    uint depositId = 0;
    uint transferId = 0;
    uint withdrawalId = 0;
    string[] tokenList;
    

    constructor() {
        mainOwner = msg.sender;
        walletOwners.push(mainOwner);
        limit = walletOwners.length - 1;
        tokenList.push("ETH");
    }

    // Mapping store address and balance of individual owners
    mapping(address => mapping(string => uint)) balance;
    mapping(address => mapping(uint => bool)) approvals;
    mapping(string => Token) tokenMapping;

    struct Token {
        string ticker;
        address tokenAddress;
    }


    struct Transfer {
        string ticker;
        address sender;
        address payable receiver;
        uint amount;
        uint id;
        uint approvals;
        uint timeOfTransaction;
    }

    Transfer[] transferRequest;

    // Events for frontend
    event walletOwnerAdded(address addedBy, address ownerAdded, uint timeOfTransaction);
    event walletOwnerRemoved(address removedBy, address ownerRemoved, uint timeOfTransaction);
    event fundsDeposited(string ticker, address sender, uint amount, uint depositId, uint timeOfTransaction);
    event fundsWithdrawed(string ticker, address sender, uint amount, uint withdrawalId, uint timeOfTransaction);
    event transferCreated(string ticker, address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event transferCancelled(string ticker, address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event transferApproved(string ticker, address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event transferExecuted(string ticker, address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event tokenAdded(address addedBy, string ticker, address tokenAddress, uint timeOfTransaction);


    modifier onlyOwners() {
        
        bool isOwner = false;
        for(uint i = 0; i < walletOwners.length; i++) {
            if(walletOwners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner == true, "Only wallet owners can call this function...");
        _;
    }

    modifier tokenExists(string memory ticker) {

        require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist...");
        _;
    }

    function addToken(string memory ticker, address _tokenAddress) public onlyOwners {

        for(uint i = 0; i < tokenList.length; i++) {
            require(keccak256(bytes(tokenList[i])) != keccak256(bytes(ticker)), "Can not add duplicate token...");
        }

        require(keccak256(bytes(ERC20(_tokenAddress).symbol())) == keccak256(bytes(ticker)));

        tokenMapping[ticker] = Token(ticker, _tokenAddress);

        tokenList.push(ticker);

        emit tokenAdded(msg.sender, ticker, _tokenAddress, block.timestamp);
    }


    // To add new owners
    function addWalletOwner(address owner) public onlyOwners {

        for(uint i = 0; i < walletOwners.length; i++) {
            if(walletOwners[i] == owner) {
                revert("Owner already exists...");
            }
        }
        walletOwners.push(owner);
        limit = walletOwners.length - 1;
        emit walletOwnerAdded(msg.sender, owner, block.timestamp);
    }
    
    // To remove owners
    function removeWalletOwner(address owner) public onlyOwners {
        bool hasBeenFound = false;
        uint ownerIndex;
        for(uint i = 0; i < walletOwners.length; i++) {
            if(walletOwners[i] == owner) {
                hasBeenFound = true;
                ownerIndex = i;
                break;
            }
        }
        require(hasBeenFound == true, "Wallet owner not found...");

        walletOwners[ownerIndex] = walletOwners[walletOwners.length -1];
        limit = walletOwners.length - 1;
        walletOwners.pop();

        emit walletOwnerRemoved(msg.sender, owner, block.timestamp);

    }
    // To deposit money
    function deposit(string memory ticker, uint amount) public payable onlyOwners  {
        require(balance[msg.sender][ticker] >= 0, "Not enough balance...");
        if(keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
            balance[msg.sender]["ETH"] = msg.value;
            
        }

        else {

            require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist...");
            balance[msg.sender][ticker] += amount;
            IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount);
            
        }

        emit fundsDeposited(ticker, msg.sender, msg.value, depositId, block.timestamp);
        depositId++;
    }



    // To withdraw money
    function withdraw(string memory ticker, uint amount) public onlyOwners {
        require(balance[msg.sender][ticker] >= amount, "Insufficient balance...");
        balance[msg.sender][ticker] -= amount;

        if(keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
            
            payable(msg.sender).transfer(amount);
        
        }
        else {
            require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist...");
            IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);
            
        }

        emit fundsWithdrawed(ticker, msg.sender, amount, withdrawalId, block.timestamp);
        withdrawalId++;
    }

    // To create transfer
    function createTransferRequest(string memory ticker, address payable receiver, uint amount) public onlyOwners {
        require(balance[msg.sender][ticker] >= amount,"Insifficient balance...");
        for(uint i = 0; i < transferRequest.length; i++) {
             require(walletOwners[i] != msg.sender, "Can not send funds to your self...");
        }

        balance[msg.sender][ticker] -= amount;
        transferRequest.push(Transfer(ticker, msg.sender, receiver, amount, transferId, 0, block.timestamp));
        transferId++;

        emit transferCreated(ticker, msg.sender, receiver, amount, transferId, 0, block.timestamp);
    }

    // To cancel the transfer
    function cancelTransfer(string memory ticker, uint id) public onlyOwners {
        bool hasBeenFound = false;
        uint transferIndex = 0;
        for(uint i = 0; i < transferRequest.length; i++) {
            if(transferRequest[i].id == id) {
                hasBeenFound = true;
                break;
            }

            transferIndex++;
        }

        require(hasBeenFound, "Transfer Id not found...");
        require(msg.sender == transferRequest[transferIndex].sender, "Only the creator cam cancel...");

        balance[msg.sender][ticker] += transferRequest[transferIndex].amount;
        transferRequest[transferIndex] = transferRequest[transferRequest.length - 1];

        emit transferCancelled(ticker, msg.sender, transferRequest[transferIndex].receiver, transferRequest[transferIndex].amount, transferRequest[transferIndex].id, transferRequest[transferIndex].approvals, transferRequest[transferIndex].timeOfTransaction);
        transferRequest.pop();
    }

    // Approve transfer function
    function approveTransferRequest(string memory ticker, uint id) public onlyOwners {
        
        //string memory ticker = transferRequest[id].ticker;
        bool hasBeenFound = false;
        uint transferIndex = 0;
        for(uint i = 0; i < transferRequest.length; i++) {
            if(transferRequest[i].id == id) {
                hasBeenFound = true;
                break;
            }

            transferIndex++;
        }

        require(hasBeenFound, "Only the transfer creator can cancel...");
        require(approvals[msg.sender][id] == false, "Can not approve twice...");
        require(transferRequest[transferIndex].sender != msg.sender, "Can not approve your own transfer...");
        
        approvals[msg.sender][id] = true;
        transferRequest[transferIndex].approvals++;
        

        emit transferApproved( ticker, msg.sender, transferRequest[transferIndex].receiver, transferRequest[transferIndex].amount, transferRequest[transferIndex].id, transferRequest[transferIndex].approvals, transferRequest[transferIndex].timeOfTransaction);

        if(transferRequest[transferIndex].approvals == limit) {
            transferFunds(ticker, transferIndex);
        }
    }

    // To transfer funds
    function transferFunds(string memory ticker, uint id) private  {
        balance[transferRequest[id].receiver][ticker] += transferRequest[id].amount;
        transferRequest[id].receiver.transfer(transferRequest[id].amount);

    if(keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
            transferRequest[id].receiver.transfer(transferRequest[id].amount);
            
        }
        else {
            IERC20(tokenMapping[ticker].tokenAddress).transfer(transferRequest[id].receiver, transferRequest[id].amount);
        }
        
        emit transferExecuted(ticker, msg.sender, transferRequest[id].receiver, transferRequest[id].amount, transferRequest[id].id, transferRequest[id].approvals, transferRequest[id].timeOfTransaction);
        transferRequest[id] = transferRequest[transferRequest.length - 1];      
        transferRequest.pop();

    }


    function getTransferRequest() public view returns(Transfer[] memory) {
        return transferRequest;
    }

    function getNumOfApprovals(uint id) public view returns(uint){
        return transferRequest[id].approvals;
    }

    function getApprovals(uint id) public view returns(bool) {
        return approvals[msg.sender][id];
    }

    function getLimit() public view returns(uint) {
        return limit;
    }



    // To get all owners
    function getWalletOwners() public view returns(address[] memory) {
        return walletOwners;
    }

    // To get balance of individual owners
    function getBalance(string memory ticker) public view returns(uint) {
        return(balance[msg.sender][ticker]);
    }

    // To get total balance of contract address
    function getContractBalance() public view returns(uint) {
        return address(this).balance;
    }
}
