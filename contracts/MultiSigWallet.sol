// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address public owner; // public variable to store the address of the owner of the contract
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
    // an event to emit when the contract ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
    }

    /**
    * @notice A modifier to restrict access to functions to only the owner of the contract.
    */
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    /**
    * @notice A modifier to restrict access to functions to only the signers of the wallet.
    */
    modifier onlySigner {
        require(isSigner[msg.sender], "Only signers can perform this action");
        _;
    }

    /**
    * @notice A constructor to initialize the contract and set the signers, required signatures and recovery address.
    * @param _signers An array of addresses representing the initial signers of the wallet.
    * @param _requiredSignatures The minimum number of signatures required to execute a transaction.
    * @param _recoveryAddress The address that can be used to recover the wallet in case of a lost or compromised account.
    */
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

    /**
    * @notice This function adds a new signer to the list of signers
    * @dev Only the contract owner can call this function.
    * @param signer The address of the signer to be added.
    */
    function addSigner(address signer) public onlyOwner {
        require(!isSigner[signer], "Address is already a signer");
        signers.push(signer);
        isSigner[signer] = true;
        emit SignerUpdate(signer, true);
    }

    /**
    * @notice Removes a signer from the list of signers.
    * @dev Only the owner of the contract can call this function.
    * @param signer The address of the signer to be removed.
    */
    function removeSigner(address signer) public onlyOwner {
        require(isSigner[signer], "The address is not a signer");
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

    /**
    * @notice Creates a new transaction with the provided destination address, value, and data.
    * @dev The function generates a unique ID for the transaction, stores the transaction details in the transactions mapping,
            adds the transaction ID to the transaction list, and emits an event to notify that a new transaction has been created.
    * @param destination The address of the destination for the transaction.
    * @param value The amount of ether to send with the transaction.
    * @param data Additional data to include with the transaction.
    * @return The unique ID of the created transaction.
    */
    function createTransaction(address destination, uint value, bytes memory data) public onlySigner returns (bytes32) {
        bytes32 id = createUniqueId(destination, value, data);
        transactions[id] = Transaction(destination, value, data, false); // store the details of the transaction
        transactionList.push(id); // add the transaction ID to the transaction list
        emit NewTransaction(id, destination, value, data); // emit an event to notify that a new transaction has been created
        return id;
    }

    /**
    * @notice Generates a unique ID for a transaction.
    * @dev This function uses the keccak256 hash function to generate a unique ID for a transaction.
    * The ID is based on the destination address, the amount of Ether to send (in wei), the data to include in the transaction,
    * and the current block timestamp.
    * @param destination The address of the destination contract.
    * @param value The amount of Ether to send (in wei).
    * @param data The data to include in the transaction.
    * @return A unique transaction ID as a bytes32 value.
    */
    function createUniqueId(address destination, uint256 value, bytes memory data) public view returns (bytes32) {
        // Hash the concatenation of the transaction parameters using the keccak256 hash function.
        bytes32 id = keccak256(abi.encodePacked(destination, value, data, block.timestamp));
        return id;
    }

    /**
    @notice This function approves a transaction identified by its id.
    @dev Only signers can call this function.
    @param id The id of the transaction to approve.
    */
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

    /**
    * @notice Approves a transaction identified by the given ID.
    * @dev The transaction must exist in the contract, and the function can only be called by a signer.
    * @param id The ID of the transaction to be approved.
    */
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
        require(count >= requiredSignatures, "Not enough signers have approved this transaction");
    }


    /**
    * @notice Allows a signer to cancel a transaction.
    * @dev The transaction must exist and must not have already been executed. The function removes the transaction from the
        transaction list and deletes its details. It also deletes the approvals for the transaction. An event is emitted to
        notify that the transaction has been cancelled.
    * @param id The ID of the transaction to be cancelled.
    */
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

    /**
    *  @notice Recovers a wallet by transferring ownership to a new address.
    * @dev Only the recovery address can call this function.
    * @param newOwner The address that will become the new owner of the wallet.
    */
    function recoverWallet(address newOwner) public {
        require(msg.sender == recoveryAddress, "Only the recovery address can call this function");
        require(newOwner != recoveryAddress, "New recovery address should not match current one");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}
