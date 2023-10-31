const { BigNumber } = require("ethers");
const { ethers, upgrades } = require("hardhat");

const red = '\x1b[31m';
const green = '\x1b[32m';
const yellow = '\x1b[33m';
const blue = '\x1b[34m';
const reset = '\x1b[0m';

function getSelectors(contract) {
  const signatures = Object.keys(contract.interface.functions);
  const selectors = signatures.reduce((acc, val) => {
    acc.push(contract.interface.getSighash(val));
    return acc;
  }, []);
  return selectors;
}

function getSelector(contract, functionName) {
  const signatures = Object.keys(contract.interface.functions);
  if (!signatures.includes(functionName)) {
      throw new Error(`Function ${functionName} does not exist on the contract.`);
  }

  return contract.interface.getSighash(functionName);
}

async function getTransactionCost(tx) {
  const receipt = await ethers.provider.getTransactionReceipt(tx.hash);
  const cost = receipt.gasUsed.mul(tx.gasPrice);
  return ethers.utils.formatEther(cost);
}

function getFunctionSignature(contract, functionName) {
  const contractFunctions = contract.interface.functions;
  if (!contractFunctions[functionName]) {
    return null;
  }
  return contract.interface.getSighash(functionName);
}

function getAppAddressesBySelectors(contract, functionNames) {
  if (!Array.isArray(functionNames)) {
    throw new Error("Expected functionNames to be an array.");
  }
  const addresses = functionNames.map(functionName => {
    const sighash = contract.interface.getSighash(functionName);
    const address = contract.functions[sighash]?.address;
    if (!address) {
        console.warn(`No address found for function ${functionName} with sighash ${sighash}`);
        return null;
    }
    return address.toHexString();
  }).filter(address => address !== null);
  
  return addresses;
}

async function initializeFeature(contractName, functionName, contractAddress, args = []) {
  const contract = await ethers.getContractAt(contractName, contractAddress);
  if (!contract[functionName]) {
      throw new Error(`-> ${contractName} - ${functionName} does not exist on the contract.`);
  }

  const tx = await contract[functionName](...args);
  await tx.wait();

  const cost = await getTransactionCost(tx);
  console.log(`-> ${contractName} - ${functionName} executed at a cost of ${cost} ETH`);
  return cost;
}

async function monitorDomainEvents(domainAddress) {
  const DomainContract = await ethers.getContractAt("Domain", domainAddress);
  DomainContract.on("DelegateBefore", (selector, feature, functionSelector, data, event) => {
      const hexString = data.slice(2); 
      const asciiString = Buffer.from(hexString, 'hex').toString('ascii');
      console.log(`${yellow}                 *** ${asciiString} - DelegateBefore Event Emitted on ${selector} to address ${feature} function ${functionSelector}${reset}`);
  });
}

let totalCost = ethers.BigNumber.from("0");

async function main() {
  let featureToAddressImplementation = {};
  const FeatureNames = [
      'FeatureStoreApp',
      'FeatureManagerApp',
      'FeatureRoutesApp',
      'AdminApp',
      'DomainManagerApp',
      'ReentrancyGuardApp',
      'ReceiverApp'
  ];

  const [owner, admin] = await ethers.getSigners();
  const Faucet = await ethers.getContractFactory('Faucet');
  const faucet = await Faucet.deploy();
  await faucet.withdrawAll();

  console.log("Deploying contracts with the account:", owner.address);

  const FeatureStoreApp = await ethers.getContractFactory("FeatureStoreApp");
  const featureStoreApp = await FeatureStoreApp.deploy();
  await featureStoreApp.deployed();
  const costForFeatureStoreApp = await getTransactionCost(featureStoreApp.deployTransaction);
  totalCost = totalCost.add(ethers.utils.parseEther(costForFeatureStoreApp));
  console.log(`FeatureStoreApp deployed to: ${featureStoreApp.address} at a cost of: ${costForFeatureStoreApp} ETH`);

  let featureIds = [];
  let features = [];

  // Deploying and registering each core feature
  for (const FeatureName of FeatureNames) {
    const Feature = await ethers.getContractFactory(FeatureName);
    const feature = (FeatureName == 'FeatureStoreApp') ? featureStoreApp : await Feature.deploy();
    if (FeatureName != 'FeatureStoreApp') {
        await feature.deployed();
        const costForFeature = await getTransactionCost(feature.deployTransaction);
        totalCost = totalCost.add(ethers.utils.parseEther(costForFeature));
        console.log(`       -> ${FeatureName} - deployed: ${feature.address} at a cost of: ${costForFeature} ETH`);
    }

    // Create a feature structure for the deployed feature
    const featureStruct = {
        id: ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], [FeatureName])),
        featureAddress: feature.address,
        functionSelectors: getSelectors(feature),
        name: FeatureName,
        version: 1,
        updateDateTime: Date.now(),
        author: owner.address,
        owner: owner.address,
        disabled: false,
        dependencies: [],
        layer: 0, //core
        chanel: 0, //public
        resourceType: 0 //any
    };

    features.push(featureStruct);

    // Register the feature in the store
    await featureStoreApp.addFeature(featureStruct);;
    console.log(`       -> ${FeatureName} - registered: ${feature.address}`);

    // Save mapping for feature's address and implementation for convenience
    featureToAddressImplementation[feature.address] = featureStruct.implementation;

    // Save feature IDs for delegation and tests
    featureIds.push(featureStruct.id);
  }

  // Deploying and registering each domain feature
  const DomainNames = [
    'Domain',
    'DomainManager'
  ];

  const FeaturesInDomain = [
      'AdminApp',
      'DomainManagerApp',
      'FeatureManagerApp',
      'FeatureRoutesApp',
      'ReceiverApp',
      'ReentrancyGuardApp'
  ];

  const DomainManager = await ethers.getContractFactory('DomainManager');
  const domainManager = await upgrades.deployProxy(DomainManager, [featureStoreApp.address]);
  await domainManager.deployed();
  const costForDomainManager = await getTransactionCost(domainManager.deployTransaction);
  totalCost = totalCost.add(ethers.utils.parseEther(costForDomainManager));
  console.log(`DomainManager deployed to: ${domainManager.address} at a cost of: ${costForDomainManager} ETH`);

  // Save mapping for feature's address and implementation for convenience
  featureToAddressImplementation[domainManager.address] = domainManager.address;

  // Create a Domain structure for the deployed DomainManager
  const domainStruct = {
      id: ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DomainManager')),
      address: domainManager.address,
      implementation: domainManager.address
  };

  // Save feature IDs for delegation and tests
  featureIds.push(domainStruct.id);

  // Register the DomainManager in the store
  await featureStoreApp.registerFeature(domainStruct.id, domainStruct.address, domainStruct.implementation);
  console.log(`DomainManager - registered: ${domainManager.address}`);

  // Deploying and registering domain contracts
  const DomainContract = await ethers.getContractFactory('Domain');
  const domain = await upgrades.deployProxy(DomainContract, [domainStruct.address]);
  await domain.deployed();
  const costForDomain = await getTransactionCost(domain.deployTransaction);
  totalCost = totalCost.add(ethers.utils.parseEther(costForDomain));
  console.log(`Domain deployed to: ${domain.address} at a cost of: ${costForDomain} ETH`);

  // Create a Domain structure for the deployed Domain
  const domainStruct2 = {
      id: ethers.utils.keccak256(ethers.utils.toUtf8Bytes('Domain')),
      address: domain.address,
      implementation: domain.address
  };

  // Save feature IDs for delegation and tests
  featureIds.push(domainStruct2.id);

  // Register the Domain in the store
  await featureStoreApp.registerFeature(domainStruct2.id, domainStruct2.address, domainStruct2.implementation);
  console.log(`Domain - registered: ${domain.address}`);

  // Deploying Domain contracts for testing
  const TestDomains = [
      'TestDomain1',
      'TestDomain2'
  ];

  const TestDomainFeatures = [
    ['AdminApp', 'ReceiverApp'],
    ['AdminApp', 'FeatureManagerApp', 'ReceiverApp']
  ];

  for (let i = 0; i < TestDomains.length; i++) {
      const TestDomain = await ethers.getContractFactory('Domain');
      const testDomain = await upgrades.deployProxy(TestDomain, [domainStruct.address]);
      await testDomain.deployed();
      const costForTestDomain = await getTransactionCost(testDomain.deployTransaction);
      totalCost = totalCost.add(ethers.utils.parseEther(costForTestDomain));
      console.log(`${TestDomains[i]} deployed to: ${testDomain.address} at a cost of: ${costForTestDomain} ETH`);

      // Create a Domain structure for the deployed TestDomain
      const domainStruct3 = {
          id: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(TestDomains[i])),
          address: testDomain.address,
          implementation: testDomain.address
      };

      // Save feature IDs for delegation and tests
      featureIds.push(domainStruct3.id);

      // Register the TestDomain in the store
      await featureStoreApp.registerFeature(domainStruct3.id, domainStruct3.address, domainStruct3.implementation);
      console.log(`${TestDomains[i]} - registered: ${testDomain.address}`);

      for (const featureName of TestDomainFeatures[i]) {
          const feature = features.find(f => ethers.utils.toUtf8String(f.id) === featureName);
          if (!feature) {
              throw new Error(`Feature ${featureName} not found.`);
          }
          await domainManager.delegate(feature.address, featureToAddressImplementation[feature.address], featureIds);
          console.log(`Delegated ${featureName} to ${testDomain.address}`);
      }
  }

  // Set feature store on the test domains
  for (const testDomainName of TestDomains) {
      const testDomain = await ethers.getContractAt("Domain", (await featureStoreApp.getFeature(testDomainName)).implementation);
      await testDomain.setFeatureStore(featureStoreApp.address);
      console.log(`Feature store set on ${testDomainName}`);
  }

  // Set feature store on the main domain
  await domain.setFeatureStore(featureStoreApp.address);
  console.log(`Feature store set on the main domain`);

  // Delegating AdminApp to all domains
  for (const testDomainName of TestDomains) {
      const testDomain = await ethers.getContractAt("Domain", (await featureStoreApp.getFeature(testDomainName)).implementation);
      const feature = features.find(f => ethers.utils.toUtf8String(f.id) === 'AdminApp');
      if (!feature) {
          throw new Error(`Feature AdminApp not found.`);
      }
      await testDomain.delegate(feature.address, featureToAddressImplementation[feature.address], featureIds);
      console.log(`Delegated AdminApp to ${testDomainName}`);
  }

  // Deploying a simple ERC20 contract for testing
  const ERC20 = await ethers.getContractFactory("ERC20");
  const erc20 = await ERC20.deploy(owner.address, 10000);
  await erc20.deployed();
  console.log(`ERC20 deployed to: ${erc20.address}`);

  // Transfer some tokens to the test domains for testing
  for (const testDomainName of TestDomains) {
      const testDomain = await ethers.getContractAt("Domain", (await featureStoreApp.getFeature(testDomainName)).implementation);
      await erc20.transfer(testDomain.address, 1000);
      console.log(`Transferred 1000 tokens to ${testDomainName}`);
  }

  // Testing function delegation from main domain to test domains
  const mainDomain = await ethers.getContractAt("Domain", (await featureStoreApp.getFeature('Domain')).implementation);
  const receiverAddress = await mainDomain.getDomainAdmin();
  const receiver = await ethers.getContractAt("ReceiverApp", receiverAddress);

  // Ensure the receiver balance is zero initially
  const receiverBalance = await erc20.balanceOf(receiverAddress);
  if (!receiverBalance.isZero()) {
      throw new Error(`ReceiverApp balance is not zero: ${receiverBalance.toString()}`);
  }

  // Call a function on ReceiverApp through delegation
  const functionSelector = getFunctionSignature(receiver, "receiveTokens");
  const encodedData = ethers.utils.defaultAbiCoder.encode(['uint256'], [500]);
  const transaction = await mainDomain.delegateCall(receiver.address, functionSelector, encodedData);
  await transaction.wait();
  console.log(`Delegated call to ReceiverApp to receive 500 tokens`);

  // Check the receiver balance after the delegation
  const newReceiverBalance = await erc20.balanceOf(receiverAddress);
  console.log(`ReceiverApp balance after delegation: ${newReceiverBalance.toString()}`);

  console.log(`Total cost: ${totalCost.toString()} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(red + "Error: " + error.message + reset);
    process.exit(1);
  });
