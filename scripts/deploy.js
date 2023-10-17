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

  const [owner, admin] = await ethers.getSigners();

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

    const DexApp = await ethers.getContractFactory('DexApp');
    const dexApp = await DexApp.deploy();
    await dexApp.deployed();
    const costForDexApp = await getTransactionCost(dexApp.deployTransaction);
    totalCost = totalCost.add(ethers.utils.parseEther(costForDexApp));

    const dexAppFunctionSelectors = getSelectors(dexApp);

    const dexAppFeatureArgs = {
        featureAddress: dexApp.address,
        action: 0, 
        functionSelectors: dexAppFunctionSelectors
    };

    extensibleFeatures.push(dexAppFeatureArgs);


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
    

    // //Sending 10 ethers to the token address
    //  const tx = await owner.sendTransaction({
    //    to: addressVickAiTokenSeedDomain,
    //    value: ethers.utils.parseEther('10')
    //  });
    //  await tx.wait();
    //  const costTransfer = await getTransactionCost(tx);
    //  console.log(`                   -> Sent 10 ETH to address: ${addressVickAiTokenSeedDomain} at a cost of: ${costTransfer} ETH`);
    //  totalCost = totalCost.add(ethers.utils.parseEther(costTransfer));

    // //const admin = "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411";
    // const sendTokensTx = await vickAiERC20TokenSeedFeature.transfer(admin.address, ethers.utils.parseUnits('10', 18));  // assuming 18 decimals
    // await sendTokensTx.wait();
    // const costForTokenTransfer = await getTransactionCost(sendTokensTx);
    // totalCost = totalCost.add(ethers.utils.parseEther(costForTokenTransfer));
    // console.log(`                   -> Sent 10 VICK-S to admin address: ${admin.address} at a cost of: ${costForTokenTransfer} ETH`);


    console.log(`               -> DexApp feature deployed: ${dexApp.address} at a cost of: ${costForDexApp} ETH`);    
    const dexAppFeature = await ethers.getContractAt('DexApp', addressVickAiTokenSeedDomain);
    const gatewayName = "VickAiGateway";
    const onlyReceiveSwapTokenAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"; // Defina o endereço adequado aqui.
    const routers = [
      {
          name: "QuickSwap",
          router: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
          enabled: true
      }
    ]; 
    const txDex = await dexAppFeature.createGateway(gatewayName, onlyReceiveSwapTokenAddress, routers);
    const receipt = await txDex.wait();
    const gatewayId = receipt.events?.find(e => e.event === 'GatewayCreated')?.args?.gatewayId;
    
    console.log(`                   -> Gateway ${gatewayName} created with ID: ${gatewayId}`);
    
    const totalTokenSupply = await vickAiERC20TokenSeedFeature.balanceOf(owner.address)
 
    const approveTx = await vickAiERC20TokenSeedFeature.approve(dexAppFeature.address, totalTokenSupply);
    await approveTx.wait();
    const costForApproval = await getTransactionCost(approveTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForApproval));
    console.log(`                   -> Approved ${totalTokenSupply} VICK-S for DexApp at a cost of: ${costForApproval} ETH`);


  const destination = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"; // Project Manager Vick AI Initial Funds Contract

  async function _createPurchOrder(preOrder, amount, price, destination, tokenBurnedOnClose) {
    const tx = await dexAppFeature.createPurchOrder(
        gatewayId,
        vickAiERC20TokenSeedFeature.address,
        preOrder,
        amount,
        price,
        tokenBurnedOnClose
    );
    await tx.wait();
    const costForOrderCreation = await getTransactionCost(tx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForOrderCreation));
    
    console.log(`                     -> Order created: Amount: ${amount}, Price: ${price}, Burned on close: ${tokenBurnedOnClose}, Cost: ${costForOrderCreation} ETH`);
  }


  // Create purchase orders based on provided information
  await _createPurchOrder(true, ethers.utils.parseUnits("256800.00", 18), ethers.utils.parseUnits("0.200000", 18), destination, ethers.utils.parseUnits("12840.00", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("311261.82", 18), ethers.utils.parseUnits("0.223030", 18), destination, ethers.utils.parseUnits("31126.18", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("251118.75", 18), ethers.utils.parseUnits("0.259800", 18), destination, ethers.utils.parseUnits("37667.81", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("358291.38", 18), ethers.utils.parseUnits("0.300590", 18), destination, ethers.utils.parseUnits("71658.28", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("228874.07", 18), ethers.utils.parseUnits("0.392710", 18), destination, ethers.utils.parseUnits("68662.22", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("266026.95", 18), ethers.utils.parseUnits("0.495810", 18), destination, ethers.utils.parseUnits("106410.78", 18));


    // Purchase 1000 Vick-S tokens using ETH from the Admin account
  const purchaseAmount = ethers.utils.parseUnits('1000', 18); 
  const requiredETH = purchaseAmount.mul(ethers.utils.parseUnits('0.495810', 18)).div(ethers.utils.parseUnits('1', 18)); // Assuming 0.495810 ETH per Vick-S token from the last purchase order

  //"swapToken(bytes32,address,address,uint256,address,address)": FunctionFragment;
  // Purchase the tokens
  const purchaseTx = await dexAppFeature.swapToken1(
      gatewayId,
      vickAiERC20TokenSeedFeature.address,
      "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // ETH as the input token
      requiredETH,
      admin.address, // tokens will be sent to the admin address
      ethers.constants.AddressZero // No airdrop
  );
  await purchaseTx.wait();
  const costForPurchase = await getTransactionCost(purchaseTx);
  totalCost = totalCost.add(costForPurchase);

  const balanceAfter = await ethers.provider.getBalance(admin.address);
  console.log(`                     -> Admin purchased 1000 Vick-S tokens at a cost of: ${ethers.utils.formatEther(balanceBefore.sub(balanceAfter))} ETH`);

    
    //const sendTokensTx2 = await vickAiERC20TokenSeedFeature.connect(admin).transfer(owner.address, ethers.utils.parseUnits('10', 18));  // assuming 18 decimals
    //await sendTokensTx2.wait();
    //const costForTokenTransfer2 = await getTransactionCost(sendTokensTx2);
    //totalCost = totalCost.add(ethers.utils.parseEther(costForTokenTransfer2));
    //console.log(`                   -> Sent 10 VICK-S to owner address: ${owner.address} at a cost of: ${costForTokenTransfer2} ETH`);

    console.log(`\n\nTotal cost for all transactions: ${ethers.utils.formatEther(totalCost)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
