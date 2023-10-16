const { ethers, upgrades } = require("hardhat");

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


async function main() {
  let totalCost = ethers.BigNumber.from("0");
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

            // Register the deployed feature in the FeatureStore
            const tx = await featureStoreApp.addFeature(featureStruct);
            const costForAddFeature = await getTransactionCost(tx);
            totalCost = totalCost.add(ethers.utils.parseEther(costForAddFeature));
            
            featureToAddressImplementation[FeatureName] = feature.address;
            featureIds.push(featureStruct.id);
            console.log(`       -> ${FeatureName} - registered id: ${featureStruct.id} at a cost of: ${costForAddFeature} ETH`);
            
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

        const bundleTx = await featureStoreApp.addBundle(coreBundle);
        const costForAddBundle = await getTransactionCost(bundleTx);
        totalCost = totalCost.add(ethers.utils.parseEther(costForAddBundle));
        
        console.log(`Core bundle registered id: ${coreBundle.id} at a cost of: ${costForAddBundle} ETH`);
        

      features= await featureStoreApp.getFeaturesByBundle(coreBundle.id);
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
      let addressGenesisDomain = domain.address;
      const costForDomain = await getTransactionCost(domain.deployTransaction);
      totalCost = totalCost.add(ethers.utils.parseEther(costForDomain));
      console.log(`Genesis domain created: ${addressGenesisDomain} at a cost of: ${costForDomain} ETH`);
  
      

    // Obtain the DomainManagerApp from the Genesis domain
    const domainManagerFeature = await ethers.getContractAt('DomainManagerApp', addressGenesisDomain);

    // Create the "Plugfy" domain using the same features as the "Genesis" domain
    const plugfyArgs = {
            owner: owner.address,
            initAddress: ethers.constants.AddressZero,
            functionSelector: "0x00000000",
            initCalldata: '0x00'
    };

    const createDomainTx = await domainManagerFeature.createDomain(addressGenesisDomain, "Plugfy", features, plugfyArgs);
    const costForCreateDomain = await getTransactionCost(createDomainTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForCreateDomain));

    const addressPlugfyDomain = await domainManagerFeature.getDomainAddress(0); 

    console.log(`   -> Genesis.Plugfy domain created: ${addressPlugfyDomain} at a cost of: ${costForCreateDomain} ETH`);


    const plugfyDomainManagerFeature = await ethers.getContractAt('DomainManagerApp', addressPlugfyDomain);
    // Create the "VickAi" subdomain of the "Plugfy" domain
    const vickAiArgs = {
            owner: owner.address,
            initAddress: ethers.constants.AddressZero,
            functionSelector: "0x00000000",
            initCalldata: '0x00'
    };

    const createVickAiTx = await plugfyDomainManagerFeature.createDomain(addressGenesisDomain, "VickAi", features, vickAiArgs);
    const costForCreateVickAi = await getTransactionCost(createVickAiTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForCreateVickAi));
    
    const addressVickAiSubdomain = await plugfyDomainManagerFeature.getDomainAddress(0);
    
    console.log(`       -> Genesis.Plugfy.VickAi subdomain created: ${addressVickAiSubdomain} at a cost of: ${costForCreateVickAi} ETH`);
    
    const vickAiDomainManagerFeature = await ethers.getContractAt('DomainManagerApp', addressVickAiSubdomain);

    // Create the "VickAi" subdomain of the "Plugfy" domain
    const vickSeedTokenArgs = {
            owner: owner.address,
            initAddress: ethers.constants.AddressZero,
            functionSelector: "0x00000000",
            initCalldata: '0x00'
    };

    let extensibleFeatures = [...features];

    // Create the "VickAi" subdomain of the "Plugfy" domain
    const ERC20App = await ethers.getContractFactory('ERC20App');
    const erc20App = await ERC20App.deploy();
    await erc20App.deployed();
    const costForERC20App = await getTransactionCost(erc20App.deployTransaction);
    totalCost = totalCost.add(ethers.utils.parseEther(costForERC20App));



    extensibleFeatures.push({
        featureAddress: erc20App.address,
        action: 0,
        functionSelectors: getSelectors(erc20App)
    });

    await vickAiDomainManagerFeature.createDomain(addressVickAiSubdomain, "TokenSeed", extensibleFeatures, vickSeedTokenArgs);
    const addressVickAiTokenSeedDomain = await vickAiDomainManagerFeature.getDomainAddress(0); // Assuming index 2 because Genesis is at index 0 and Plugfy is at index 1

    console.log("           -> Genesis.Plugfy.VickAi.TokenSeed subdomain created: " + addressVickAiTokenSeedDomain);    
    console.log(`               -> ERC20 feature deployed: ${erc20App.address} at a cost of: ${costForERC20App} ETH`); 


    //const AdminAppFeature = await ethers.getContractAt('AdminApp', addressVickAiTokenSeedDomain);

    // let functionNamesToGuard = ["transfer(address,uint256)", "approve(address,uint256)", "transferFrom(address,address,uint256), burn(uint256), burnFrom(address,uint256)"]; 
    //    for (let functionName of functionNamesToGuard) {
    //     const functionSelector = getSelector(erc20App, functionName);
    //     const txSetGuard = await AdminAppFeature.setReentrancyGuard(functionSelector, true);
    //     const costForSetGuard = await getTransactionCost(txSetGuard);
    //     totalCost = totalCost.add(ethers.utils.parseEther(costForSetGuard));
    //     console.log(`                 - Set Reentrancy Guard for function ${functionName} at a cost of: ${costForSetGuard} ETH`);
    // }    
    
    const vickAiERC20TokenSeedFeature = await ethers.getContractAt('ERC20App', addressVickAiTokenSeedDomain);
    const initTx = await vickAiERC20TokenSeedFeature._init("Vick Ai Seed","VICK-S", 2500000000000000000000000n, 18);
    const costForInit = await getTransactionCost(initTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForInit));
    
    console.log(`                   -> Genesis.Plugfy.VickAi.TokenSeed initialized - Name: ${await vickAiERC20TokenSeedFeature.name()} (${await vickAiERC20TokenSeedFeature.symbol()}) - Total Supply: ${await vickAiERC20TokenSeedFeature.balanceOf(owner.address)} at a cost of: ${costForInit} ETH`);
    

    //Sending 10 ethers to the token address
     const tx = await owner.sendTransaction({
       to: addressVickAiTokenSeedDomain,
       value: ethers.utils.parseEther('10')
     });
     await tx.wait();
     const costTransfer = await getTransactionCost(tx);
     console.log(`                   -> Sent 10 ETH to address: ${addressVickAiTokenSeedDomain} at a cost of: ${costTransfer} ETH`);
     totalCost = totalCost.add(ethers.utils.parseEther(costTransfer));

    console.log(`\n\nTotal cost for all transactions: ${ethers.utils.formatEther(totalCost)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
