const { ethers } = require('hardhat');

async function main() {
  const signers = [
    '0x1234567890123456789012345678901234567890',
    '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd'
  ];
  const requiredSignatures = 2; // set the required number of signatures for a transaction here
  const recoveryAddress = '0x9876543210987654321098765432109876543210'; // set the recovery address here

  const MultiSigWallet = await ethers.getContractFactory('MultiSigWallet');
  const multiSigWallet = await MultiSigWallet.deploy(signers, requiredSignatures, recoveryAddress);

  console.log('MultiSigWallet deployed to:', multiSigWallet.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });