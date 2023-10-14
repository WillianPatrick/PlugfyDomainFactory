const { ethers, upgrades } = require("hardhat");

function getSelectors(contract) {
  const signatures = Object.keys(contract.interface.functions);
  const selectors = signatures.reduce((acc, val) => {
    acc.push(contract.interface.getSighash(val));
    return acc;
  }, []);
  return selectors;
}

function getFunctionSignature(contract, functionName) {
  const contractFunctions = contract.interface.functions;
  if (!contractFunctions[functionName]) {
    return null;
  }
  return contract.interface.getSighash(functionName);
}

function getAppAddressesBySelectors(contract, functionNames) {
  const addresses = functionNames.map(functionName => {
    const sighash = contract.interface.getSighash(functionName);
    return contract.functions[sighash]?.address?.toHexString() ?? null;
  }).filter(address => address !== null);
  
  return addresses;
}

async function main() {

let featureToAddressImplementation = {};
const FeatureNames = [
    'FeatureStoreApp',
    'FeatureManagerApp',
    'FeatureRoutesApp',
    'OwnershipApp',
    'AdminApp',
    'DomainManagerApp'
];

let coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
let featuresBundle;

  const [owner] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", owner.address);
  
  // Deploy FeatureStoreApp
  const FeatureStoreApp = await ethers.getContractFactory("FeatureStoreApp");
  const featureStoreApp = await FeatureStoreApp.deploy();
  await featureStoreApp.deployed();
  console.log("FeatureStoreApp deployed to:", featureStoreApp.address);


  let featureIds = [];

        // Deploying and registering each core feature
        for (const FeatureName of FeatureNames) {
            const Feature = await ethers.getContractFactory(FeatureName);
            const feature = (FeatureName == 'FeatureStoreApp') ? featureStoreApp : await Feature.deploy();

            if((FeatureName != 'FeatureStoreApp')){
              await feature.deployed();
              console.log("       -> " + FeatureName + " - deployed: "+ feature.address);
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

            // Register the deployed feature in the FeatureStore
            await featureStoreApp.addFeature(featureStruct);
            featureToAddressImplementation[FeatureName] = feature.address;
            featureIds.push(featureStruct.id);
            console.log("       -> " + FeatureName + " - registred id: "+ featureStruct.id);
        };

        // Creating the Core bundle
        const coreBundle = {
            id: ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core'])),
            functions: [], // Assuming you will add function IDs here if necessary
            features: featureIds,
            bundles: [], // Assuming you will add other bundle IDs here if necessary
            name: "Core",
            version: 1,
            updateDateTime: Date.now(),
            author: owner.address,
            owner: owner.address,
            disabled: false,
            layer: 0, //core
            chanel: 0, //public
            resourceType: 0 //domain
        };

        await featureStoreApp.addBundle(coreBundle);

    console.log("Core bundle registered id: "+ coreBundle.id);

      const features = await featureStoreApp.getFeaturesByBundle(coreBundle.id);
      let _args = {
          owner: owner.address,
          initAddress: ethers.constants.AddressZero,
          functionSelector: "0x00000000",
          initCalldata: '0x00',
          initializeForce: false
      };


      const Domain = await ethers.getContractFactory('Domain');
      const domain = await Domain.deploy(ethers.constants.AddressZero, "Genesis", features, _args);
      await domain.deployed();
      
      let addressDomain = domain.address;

    console.log("Genesis domain created: "+ addressDomain);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
