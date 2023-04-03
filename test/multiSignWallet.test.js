const {
  expect
} = require("chai");
const {
  ethers
} = require("hardhat");

describe("MultiSigWallet", function () {
  beforeEach(async function () {
    // Deploy the MultiSigWallet contract
    [owner, signer1, signer2, recoveryAddress] = await ethers.getSigners();
    requiredSignatures = 2;
    multiSigWallet = await ethers.getContractFactory("MultiSigWallet");
    multiSigWallet = await multiSigWallet.deploy([signer1.address, owner.address], requiredSignatures, recoveryAddress.address);
    destination = ethers.Wallet.createRandom().address;
    value = ethers.utils.parseEther("1.0");
    data = "0x1234";
  });

  describe("Deployment", function () {
    it("Should set the owner correctly", async function () {
      expect(await multiSigWallet.owner()).to.equal(owner.address);
    });

    it("Should set the signers correctly", async function () {
      expect(await multiSigWallet.signers(0)).to.equal(signer1.address);
      expect(await multiSigWallet.signers(1)).to.equal(owner.address);
    });

    it("Should set the required signatures correctly", async function () {
      expect(await multiSigWallet.requiredSignatures()).to.equal(requiredSignatures);
    });

    it("Should set the recovery address correctly", async function () {
      expect(await multiSigWallet.recoveryAddress()).to.equal(recoveryAddress.address);
    });
  });

  describe("addSigner", function () {
    it("Should add a new signer", async function () {
      const newSigner = ethers.Wallet.createRandom().address;
      await multiSigWallet.addSigner(newSigner);
      expect(await multiSigWallet.isSigner(newSigner)).to.equal(true);
      expect(await multiSigWallet.signers(2)).to.equal(newSigner);
    });

    it("Should revert when adding an existing signer", async function () {
      await expect(multiSigWallet.addSigner(signer1.address)).to.be.revertedWith("Address is already a signer");
    });

    it("Should revert when not called by the owner", async function () {
      const attacker = signer1;
      await expect(multiSigWallet.connect(attacker).addSigner(attacker.address)).to.be.revertedWith("Only the owner can perform this action");
    });
  });

  describe("removeSigner", function () {
    it("Should remove a signer", async function () {
      const newSigner = ethers.Wallet.createRandom().address;
      await multiSigWallet.addSigner(newSigner)
      const signerToRemove = signer1.address;
      await multiSigWallet.removeSigner(signerToRemove);
      expect(await multiSigWallet.isSigner(signerToRemove)).to.equal(false);
      expect(await multiSigWallet.signers(2).length).to.be.undefined;
    });

    it("Should revert when removing a non-existent signer", async function () {
      const nonExistentSigner = ethers.Wallet.createRandom().address;
      await expect(multiSigWallet.removeSigner(nonExistentSigner)).to.be.revertedWith("The address is not a signer");
    });

    it("Should revert when removing a signer that will result in required signatures being higher than number of signers", async function () {
      await expect(multiSigWallet.removeSigner(signer1.address)).to.be.revertedWith("Cannot remove signer, minimum required signers will not be met");
    });

    it("Should revert when not called by the owner", async function () {
      const attacker = signer1;
      await expect(multiSigWallet.connect(attacker).removeSigner(signer2.address)).to.be.revertedWith("Only the owner can perform this action");
    });
  });

  describe("createTransaction", function () {
    it("should create a new transaction with the provided destination, value, and data", async function () {
      await multiSigWallet.createTransaction(destination, value, data);
      let txId = await multiSigWallet.transactionList(0);
      // Verify that the transaction details were stored correctly
      const transaction = await multiSigWallet.transactions(txId);
      expect(transaction.destination).to.equal(destination);
      expect(transaction.value).to.equal(value);
      expect(transaction.data).to.equal(data);
      expect(transaction.executed).to.equal(false);

      // Verify that a NewTransaction event was emitted
      const events = await multiSigWallet.queryFilter("NewTransaction");
      expect(events.length).to.equal(1);
      expect(events[0].args.id).to.equal(txId);
      expect(events[0].args.destination).to.equal(destination);
      expect(events[0].args.value).to.equal(value);
      expect(events[0].args.data).to.equal(data);
    });

    it("should revert if called by a non-signer", async function () {
      const nonSigner = await ethers.getSigner(4);

      const destination = await (await ethers.getSigner(5)).address;
      const value = ethers.utils.parseEther("1.0");
      const data = "0x1234";

      await expect(multiSigWallet.connect(nonSigner).createTransaction(destination, value, data)).to.be.revertedWith("Only signers can perform this action");
    });
  });

  describe("createUniqueId", function () {
    it("should return the same ID for the same parameters", async function () {
      const destination = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
      const value = 100;
      const data = "0xabcdef";

      const id1 = await multiSigWallet.createUniqueId(destination, value, data);
      const id2 = await multiSigWallet.createUniqueId(destination, value, data);

      expect(id1).to.equal(id2);
    });

    it("should return different IDs for different parameters", async function () {
      const destination1 = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2";
      const value1 = 100;
      const data1 = "0xabcdef";

      const destination2 = "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db";
      const value2 = 200;
      const data2 = "0x123456";

      const id1 = await multiSigWallet.createUniqueId(destination1, value1, data1);
      const id2 = await multiSigWallet.createUniqueId(destination2, value2, data2);

      expect(id1).to.not.equal(id2);
    });
  });

  describe("approveTransaction", function () {
    it("should revert if the transaction ID does not exist", async function () {
      let txId = await multiSigWallet.createUniqueId(ethers.Wallet.createRandom().address, ethers.utils.parseEther("1.0"), "0x1234")
      await expect(multiSigWallet.approveTransaction(txId)).to.be.revertedWith("Transaction does not exist");
    });
    it("should not approve a transaction if the sender is not a signer", async function () {
      const destination = owner.address;
      const value = ethers.utils.parseEther("1");
      const data = "0x";
      await multiSigWallet.createTransaction(destination, value, data);
      let txId = await multiSigWallet.transactionList(0);
      const newSigner = await ethers.getSigner();

      await expect(multiSigWallet.connect(signer2).approveTransaction(txId)).to.be.revertedWith("Only signers can perform this action");
    });
    it("should emit an Approval event", async function () {
      await multiSigWallet.createTransaction(destination, value, data);
      let txId = await multiSigWallet.transactionList(0);

      await expect(multiSigWallet.approveTransaction(txId))
        .to.emit(multiSigWallet, "Approval")
        .withArgs(txId, owner.address);
    });

    it("should update the approvals mapping", async function () {
      await multiSigWallet.createTransaction(destination, value, data);
      let txId = await multiSigWallet.transactionList(0);
      await multiSigWallet.approveTransaction(txId);
      expect(await multiSigWallet.approvals(txId, owner.address)).to.be.true;
    });


    it("should emit an Execution event and execute the transaction when enough signers approve it", async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);

      // approve the transaction with signer1
      await multiSigWallet.connect(signer1).approveTransaction(txId);
      expect(await multiSigWallet.approvals(txId, signer1.address)).to.equal(true);
      // try to execute the transaction with only one approval
      await expect(multiSigWallet.executeTransaction(txId)).to.be.revertedWith("Not enough signers have approved this transaction");
      let transaction = await multiSigWallet.transactions(txId)
      // check that the transaction has not been executed yet
      expect(transaction.executed).to.be.false;

      // approve the transaction with owner
      await multiSigWallet.connect(owner).approveTransaction(txId);
      expect(await multiSigWallet.approvals(txId, owner.address)).to.equal(true);

      // check that the transaction has been executed
      const tx = await multiSigWallet.transactions(txId);
      expect(tx.executed).to.equal(true);
      // check that the Execution event has been emitted
      const events = await multiSigWallet.queryFilter("Execution", tx.blockHash);
      expect(events.length).to.equal(1);
      expect(events[0].args.id).to.equal(txId);
    });
  });

  describe('executeTransaction', function () {
    it('should execute a transaction if the required number of signers have approved it', async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);

      // Approve the transaction
      await multiSigWallet.connect(signer1).approveTransaction(txId);
      await multiSigWallet.connect(owner).approveTransaction(txId);

      // Check that the transaction was executed
      const transaction = await multiSigWallet.transactions(txId);
      expect(transaction.executed).to.be.true;

      // check that the Execution event has been emitted
      const events = await multiSigWallet.queryFilter("Execution", transaction.blockHash);
      expect(events.length).to.equal(1);
      expect(events[0].args.id).to.equal(txId);
    });

    it('should not execute a transaction if the required number of signers have not approved it', async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);

      // Approve the transaction
      await multiSigWallet.connect(signer1).approveTransaction(txId);

      // Try to execute the transaction
      await expect(multiSigWallet.executeTransaction(txId)).to.be.revertedWith('Not enough signers have approved this transaction');

      // Check that the transaction was not executed
      const transaction = await multiSigWallet.transactions(txId);
      expect(transaction.executed).to.be.false;
    });

    it('should not execute a transaction that has already been executed', async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);

      // Approve the transaction
      await multiSigWallet.connect(signer1).approveTransaction(txId);
      await multiSigWallet.connect(owner).approveTransaction(txId);

      // Try to execute the transaction again
      await expect(multiSigWallet.executeTransaction(txId)).to.be.revertedWith('Transaction has already been executed');

    });
  });
  describe("cancelTransaction function", function () {
    it("should revert if the transaction has already been executed", async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);

      await multiSigWallet.connect(signer1).approveTransaction(txId);
      await multiSigWallet.connect(owner).approveTransaction(txId);
      await expect(multiSigWallet.connect(owner).cancelTransaction(txId)).to.be.revertedWith("Transaction has already been executed");
    });

    it("should revert if the transaction does not exist", async function () {
      let txId = await multiSigWallet.createUniqueId(destination, 0, data);
      await expect(multiSigWallet.connect(owner).cancelTransaction(txId)).to.be.revertedWith("Transaction does not exist");
    });

    it("should cancel the transaction if it has been approved by enough signers but not yet executed", async function () {
      await multiSigWallet.createTransaction(destination, 0, data);
      let txId = await multiSigWallet.transactionList(0);
      await multiSigWallet.connect(signer1).approveTransaction(txId);
      await multiSigWallet.connect(owner).cancelTransaction(txId);

      // check that the Cancellation event has been emitted
      const transaction = await multiSigWallet.transactions(txId);
      const events = await multiSigWallet.queryFilter("Cancellation", transaction.blockHash);
      expect(events.length).to.equal(1);
      expect(events[0].args.id).to.equal(txId);
    });
  });

  describe("recoverWallet", function () {
    it("should recover the wallet", async function () {
      let newOwner = ethers.Wallet.createRandom().address;
      await multiSigWallet.connect(recoveryAddress).recoverWallet(newOwner);
      // Check that the wallet is recovered
      expect(await multiSigWallet.owner()).to.equal(newOwner);
    });

    it("should not recover the wallet when not called by the recovery address", async function () {
      let newOwner = ethers.Wallet.createRandom().address;
      await expect(multiSigWallet.connect(signer1).recoverWallet(newOwner)).to.be.revertedWith("Only the recovery address can call this function");
    });

    it("should be reverted if the new recovery address match the current one", async function () {
      await expect(multiSigWallet.connect(recoveryAddress).recoverWallet(recoveryAddress.address)).to.be.revertedWith("New recovery address should not match current one");
    });
  });
});