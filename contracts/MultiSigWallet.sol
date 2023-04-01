// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address public owner;
    address[] public signers; // an array to store the addresses of the signers
    uint public requiredSignatures; // the number of required signatures to execute a transaction
    mapping (address => bool) public isSigner; // a mapping to check if an address is a signer or not
    mapping (bytes32 => Transaction) public transactions; // a mapping to store the details of each transaction
    mapping (bytes32 => mapping (address => bool)) public approvals; // a mapping to check if a signer has approved a transaction
    bytes32[] public transactionList; // an array to store the IDs of each transaction
    address public recoveryAddress; // the address that can be used to recover the wallet

    // an event to emit when a signer is added or removed
    event SignerUpdate(address indexed signer, bool indexed isSigner);
    // an event to emit when a new transaction is created
    event NewTransaction(bytes32 indexed id, address indexed destination, uint value, bytes data);
    // an event to emit when a transaction is approved
    event Approval(bytes32 indexed id, address indexed signer);
    // an event to emit when a transaction is executed
    event Execution(bytes32 indexed id);
    // an event to emit when a transaction is cancelled
    event Cancellation(bytes32 indexed id);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlySigner {
        require(isSigner[msg.sender], "Only signers can perform this action");
        _;
    }

    constructor(address[] memory _signers, uint _requiredSignatures, address _recoveryAddress) {
        require(_signers.length > 0 && _requiredSignatures > 0 && _requiredSignatures <= _signers.length, "Invalid input");

        owner = msg.sender;
        // initialize the signers array and the isSigner mapping
        for (uint i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            signers.push(signer);
            isSigner[signer] = true;
            emit SignerUpdate(signer, true);
        }

        requiredSignatures = _requiredSignatures;
        recoveryAddress = _recoveryAddress;
    }

    // a function to add a signer
    function addSigner(address signer) public onlyOwner {
        require(!isSigner[signer], "Address is already a signer");
        signers.push(signer);
        isSigner[signer] = true;
        emit SignerUpdate(signer, true);
    }

    // a function to remove a signer
    function removeSigner(address signer) public onlyOwner {
        require(isSigner[signer], "Address is not a signer");
        require(signers.length > requiredSignatures, "Cannot remove signer, minimum required signers will not be met");
        
        // remove the signer from the signers array and update the isSigner mapping
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                isSigner[signer] = false;
                emit SignerUpdate(signer, false);
                break;
            }
        }
    }

    // a function to create a new transaction
    function createTransaction(address destination, uint value, bytes memory data) public onlySigner returns (bytes32) {
        bytes32 id = keccak256(abi.encodePacked(destination, value, data, block.timestamp)); // generate a unique ID for the transaction
        transactions[id] = Transaction(destination, value, data, false); // store the details of the transaction
        transactionList.push(id); // add the transaction ID to the transaction list
        emit NewTransaction(id, destination, value, data); // emit an event to notify that a new transaction has been created
        return id;
    }

    // a function to approve a transaction
    function approveTransaction(bytes32 id) public onlySigner {
        require(transactions[id].destination != address(0), "Transaction does not exist");

        approvals[id][msg.sender] = true; // mark the transaction as approved by the signer
        emit Approval(id, msg.sender); // emit an event to notify that the transaction has been approved

        // check if the transaction has enough approvals to be executed
        uint count = 0;
        for (uint i = 0; i < signers.length; i++) {
            if (approvals[id][signers[i]]) {
                count++;
            }
            if (count == requiredSignatures) {
                executeTransaction(id); // execute the transaction if enough signers have approved
                break;
            }
        }
    }

    // a function to execute a transaction
    function executeTransaction(bytes32 id) public onlySigner {
        require(transactions[id].destination != address(0), "Transaction does not exist");
        require(!transactions[id].executed, "Transaction has already been executed");
        
        // check if the transaction has enough approvals to be executed
        uint count = 0;
        for (uint i = 0; i < signers.length; i++) {
            if (approvals[id][signers[i]]) {
                count++;
            }
            if (count == requiredSignatures) {
                transactions[id].executed = true; // mark the transaction as executed
                (bool success, ) = transactions[id].destination.call{value: transactions[id].value}(transactions[id].data); // execute the transaction
                require(success, "Transaction execution failed");
                emit Execution(id); // emit an event to notify that the transaction has been executed
                break;
            }
        }
    }

    // a function to cancel a transaction
    function cancelTransaction(bytes32 id) public onlySigner {
        require(transactions[id].destination != address(0), "Transaction does not exist");
        require(!transactions[id].executed, "Transaction has already been executed");

        // remove the transaction from the transaction list and delete its details
        for (uint i = 0; i < transactionList.length; i++) {
            if (transactionList[i] == id) {
                transactionList[i] = transactionList[transactionList.length - 1];
                transactionList.pop();
                delete transactions[id];
                break;
            }
        }

        // delete the approvals for the transaction
        for (uint i = 0; i < signers.length; i++) {
            approvals[id][signers[i]] = false;
        }

        emit Cancellation(id); // emit an event to notify that the transaction has been cancelled
    }

    function recoverWallet(address newOwner) public {
        require(msg.sender == recoveryAddress, "Only the recovery address can call this function");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}
