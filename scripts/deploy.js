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
  const contract = await ethers.getContractAt(contractName, contractAddress); // Mude 'Contract' para o nome real do seu contrato ou mantenha assim se for genérico
  if (!contract[functionName]) {
      throw new Error(`               -> ${contractName} - ${functionName} does not exist on the contract.`);
  }

  const tx = await contract[functionName](...args);
  await tx.wait();

  const cost = await getTransactionCost(tx);
  console.log(`               -> ${contractName} - ${functionName} executed at a cost of ${cost} ETH`);
  return cost;
}

async function monitorDomainEvents(domainAddress) {
  const DomainContract = await ethers.getContractAt("Domain", domainAddress);
  DomainContract.on("DelegateBefore", (selector, feature, functionSelector, data, event) => {
      const hexString = data.slice(2); 
      const asciiString = Buffer.from(hexString, 'hex').toString('ascii');
      console.log(`${yellow}                 *** ${asciiString} - DelegateBefore Event Emitted on ${selector} to address ${feature} function ${functionSelector}${reset}`);
  });



  // // Listen for DelegateAfter events
  // DomainContract.on("DelegateAfter", (contractAddress, feature, functionSelector, data, event) => {
  //     console.log("DelegateAfter Event Emitted:");
  //     console.log("Contract Address:", contractAddress);
  //     console.log("Feature:", feature);
  //     console.log("Function Selector:", functionSelector);
  //     // Process event. For example, save it to a database or notify an external system.
  // });

  //console.log(`             -> Monitoring events for Domain contract at address ${domainAddress}...`);
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
    'ReentrancyGuardApp'
];

let coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
let featuresBundle;

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

    //   const ReentranceGuardAppFeature2 = await ethers.getContractAt('ReentrancyGuardApp', addressGenesisDomain);

    // const initSecTx2 = await ReentranceGuardAppFeature2._initReentrancyGuard();
    // const costForSecInit2 = await getTransactionCost(initSecTx2);
    // totalCost = totalCost.add(ethers.utils.parseEther(costForSecInit2));
    
    // console.log(`   -> Reentrancy Guard feature initialized at a cost of: ${costForSecInit2} ETH`);
      
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('AdminApp','_initAdminApp', addressGenesisDomain, [])));
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('DomainManagerApp','_initDomainManagerApp', addressGenesisDomain, [])));
    // Obtain the DomainManagerApp from the Genesis domain
    await monitorDomainEvents(addressGenesisDomain);
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
    monitorDomainEvents(addressPlugfyDomain);

    console.log(`   -> Genesis.Plugfy domain created: ${addressPlugfyDomain} at a cost of: ${costForCreateDomain} ETH`);
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('AdminApp','_initAdminApp', addressPlugfyDomain, [])));
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('ReentrancyGuardApp','_initReentrancyGuard', addressPlugfyDomain, [])));


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
    await monitorDomainEvents(addressVickAiSubdomain);
    console.log(`       -> Genesis.Plugfy.VickAi subdomain created: ${addressVickAiSubdomain} at a cost of: ${costForCreateVickAi} ETH`);
    
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('AdminApp','_initAdminApp', addressVickAiSubdomain, [])));
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('ReentrancyGuardApp','_initReentrancyGuard', addressVickAiSubdomain, [])));


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

    const createDomainTx2 = await vickAiDomainManagerFeature.createDomain(addressVickAiSubdomain, "TokenSeed", extensibleFeatures, vickSeedTokenArgs);
    const costCreateDomainTx2 = await getTransactionCost(createDomainTx2);
    totalCost = totalCost.add(ethers.utils.parseEther(costCreateDomainTx2));
    const addressVickAiTokenSeedDomain = await vickAiDomainManagerFeature.getDomainAddress(0); // Assuming index 2 because Genesis is at index 0 and Plugfy is at index 1
    await monitorDomainEvents(addressVickAiTokenSeedDomain);
    console.log(`           -> Genesis.Plugfy.VickAi.TokenSeed subdomain created: ` + addressVickAiTokenSeedDomain  +` at a cost of: ${costCreateDomainTx2} ETH`);
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('AdminApp','_initAdminApp', addressVickAiTokenSeedDomain, [])));
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
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('ERC20App','_initERC20', vickAiERC20TokenSeedFeature.address, ["Vick Ai Seed", "VICK-S", 2500000000000000000000000n, 18])));
  
    const ReentranceGuardAppFeature = await ethers.getContractAt('ReentrancyGuardApp', addressVickAiTokenSeedDomain);
    totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('ReentrancyGuardApp','_initReentrancyGuard', ReentranceGuardAppFeature.address, [])));



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

    const initDexTx = await dexAppFeature._initDex("0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270");
    const costForDexInit = await getTransactionCost(initDexTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForDexInit));
    
    console.log(`                   -> DexApp feature initialized at a cost of: ${costForDexInit} ETH`);
    


    const gatewayName = "VickAiGateway";
    const onlyReceiveSwapTokenAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"; 
    const routers = [
      {
          name: "QuickSwap",
          router: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
          enabled: true
      }
    ]; 
    const txDex = await dexAppFeature.createGateway(gatewayName, onlyReceiveSwapTokenAddress, routers);
    const recipt = await txDex.wait();
    const gatewayId = recipt.events?.find(e => e.event === 'GatewayCreated')?.args?.gatewayId;
    const costTxDex = await getTransactionCost(txDex);
    totalCost = totalCost.add(ethers.utils.parseEther(costTxDex));
    console.log(`                   -> Gateway ${gatewayName} created with ID: ${gatewayId} at a cost of: ${costTxDex} ETH`);
    
    const totalTokenSupply = await vickAiERC20TokenSeedFeature.balanceOf(owner.address)
 
    const approveTx = await vickAiERC20TokenSeedFeature.approve(dexAppFeature.address, totalTokenSupply);
    await approveTx.wait();
    const costForApproval = await getTransactionCost(approveTx);
    totalCost = totalCost.add(ethers.utils.parseEther(costForApproval));
    console.log(`                   -> Approved ${totalTokenSupply} VICK-S for DexApp at a cost of: ${costForApproval} ETH`);


    const txDexDestination = await dexAppFeature.setTokenDestination(gatewayId, addressVickAiTokenSeedDomain, addressVickAiSubdomain);
    await txDexDestination.wait();
    const costFortxDexDestination = await getTransactionCost(txDexDestination);
    totalCost = totalCost.add(ethers.utils.parseEther(costFortxDexDestination));
    console.log(`                   -> Set destination swap sales amount to ${vickAiERC20TokenSeedFeature.address} at a cost of: ${costFortxDexDestination} ETH`);

  async function _createPurchOrder(preOrder, amount, price, tokenBurnedOnClose, account) {
    if(account == undefined){
      account = owner;
    }

    const tx = await dexAppFeature.connect(account).createPurchOrder(
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
    
    console.log(`                     -> Account: ${account.address} Order created: Amount: ${amount}, Price: ${price}, Burned on close: ${tokenBurnedOnClose}, Cost: ${costForOrderCreation} ETH`);
  }

  // Create purchase orders based on provided information
  await _createPurchOrder(true, ethers.utils.parseUnits("256800.00", 18), ethers.utils.parseUnits("0.200000", 18), ethers.utils.parseUnits("12840.00", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("311261.82", 18), ethers.utils.parseUnits("0.223030", 18), ethers.utils.parseUnits("31126.18", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("251118.75", 18), ethers.utils.parseUnits("0.259800", 18), ethers.utils.parseUnits("37667.81", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("358291.38", 18), ethers.utils.parseUnits("0.300590", 18), ethers.utils.parseUnits("71658.28", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("228874.07", 18), ethers.utils.parseUnits("0.392710", 18), ethers.utils.parseUnits("68662.22", 18));
  await _createPurchOrder(true, ethers.utils.parseUnits("266026.95", 18), ethers.utils.parseUnits("0.495810", 18), ethers.utils.parseUnits("106410.78", 18));

  const txMinPrice = await dexAppFeature.setMinSalesPriceTokenUnit(gatewayId, addressVickAiTokenSeedDomain, 495810000000000000n);
  await txMinPrice.wait();
  const costFortxMinPrice = await getTransactionCost(txMinPrice);
  totalCost = totalCost.add(ethers.utils.parseEther(costFortxMinPrice));
  console.log(`                   -> Set min price unit Vick Seed Token on create sales order 0.49581 at a cost of: ${costFortxMinPrice} ETH`);

  const txEnabledMinPrice = await dexAppFeature.setEnabledMinSalesPriceTokenUnit(gatewayId, addressVickAiTokenSeedDomain, true);
  await txEnabledMinPrice.wait();
  const costFortxEnabledMinPrice = await getTransactionCost(txEnabledMinPrice);
  totalCost = totalCost.add(ethers.utils.parseEther(costFortxEnabledMinPrice));
  console.log(`                   -> Set enabled min price rule at a cost of: ${costFortxEnabledMinPrice} ETH`);

  let currentVickSOwnerBalance = await vickAiERC20TokenSeedFeature.balanceOf(owner.address);
  const addAirDropAmount = await dexAppFeature.addAirDropAmount(gatewayId, dexAppFeature.address, currentVickSOwnerBalance);
  await addAirDropAmount.wait();
  const costaddAirDropAmount = await getTransactionCost(addAirDropAmount);
  totalCost = totalCost.add(ethers.utils.parseEther(costaddAirDropAmount));
  console.log(`                   -> Added ${currentVickSOwnerBalance} VICK-S for Airdrop at a cost of: ${costaddAirDropAmount} ETH`);

  const addAirDropFactor1 = await dexAppFeature.setAirdropFactor(gatewayId, vickAiERC20TokenSeedFeature.address, ethers.utils.parseUnits("100", 18), 10);
  await addAirDropFactor1.wait();
  const costaddAirDropFactor1 = await getTransactionCost(addAirDropFactor1);
  totalCost = totalCost.add(ethers.utils.parseEther(costaddAirDropFactor1));
  console.log(`                   -> Added base 100 VICK-S for factor 10 on Airdrop at a cost of: ${costaddAirDropFactor1} ETH`);

  const addAirDropFactor2 = await dexAppFeature.setAirdropFactor(gatewayId, vickAiERC20TokenSeedFeature.address, ethers.utils.parseUnits("250", 18), 8);
  await addAirDropFactor2.wait();
  const costaddAirDropFactor2 = await getTransactionCost(addAirDropFactor2);
  totalCost = totalCost.add(ethers.utils.parseEther(costaddAirDropFactor2));
  console.log(`                   -> Added base 250 VICK-S for factor 8 on Airdrop at a cost of: ${costaddAirDropFactor2} ETH`);
  
  const addAirDropFactor3 = await dexAppFeature.setAirdropFactor(gatewayId, vickAiERC20TokenSeedFeature.address, ethers.utils.parseUnits("500", 18), 6);
  await addAirDropFactor3.wait();
  const costaddAirDropFactor3 = await getTransactionCost(addAirDropFactor3);
  totalCost = totalCost.add(ethers.utils.parseEther(costaddAirDropFactor3));
  console.log(`                   -> Added base 500 VICK-S for factor 6 on Airdrop at a cost of: ${costaddAirDropFactor3} ETH`);
  
  const addAirDropFactor4 = await dexAppFeature.setAirdropFactor(gatewayId, vickAiERC20TokenSeedFeature.address, ethers.utils.parseUnits("1000", 18), 4);
  await addAirDropFactor4.wait();
  const costaddAirDropFactor4 = await getTransactionCost(addAirDropFactor4);
  totalCost = totalCost.add(ethers.utils.parseEther(costaddAirDropFactor4));
  console.log(`                   -> Added base 1000 VICK-S for factor 4 on Airdrop at a cost of: ${costaddAirDropFactor4} ETH`);  

// const USDCContract = await ethers.getContractAt('ERC20', '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'); // The address of USDC
//  // Calculate the required amount of USDC for purchasing 1000 Vick-S tokens
//  const purchaseAmount = ethers.utils.parseUnits('167237297', 18); 
//  const requiredUSDC = ethers.utils.parseUnits('515500', 6);//purchaseAmount.mul(ethers.utils.parseUnits('0.200000', 6)).div(ethers.utils.parseUnits('1', 18)); // Assuming 0.495810 USDC per Vick-S token from the last purchase order
//  console.log(`                     -> Admin USDC balance of: ${await USDCContract.balanceOf(admin.address)}`);
//  //Approve the DEX contract to spend the required amount of USDC on behalf of the Admin
 
//  const approveTx2 = await USDCContract.connect(admin).approve(vickAiERC20TokenSeedFeature.address, requiredUSDC);
//  await approveTx2.wait();
//  const costForApproval2 = await getTransactionCost(approveTx2);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForApproval));
//  console.log(`                     -> Approved DexApp to spend ${requiredUSDC} USDC at a cost of: ${costForApproval2} ETH`);


//  //Purchase 1000 Vick-S tokens using USDC from the Admin account
//  const purchaseTx = await dexAppFeature.connect(admin).swapToken(
//      gatewayId,
//      vickAiERC20TokenSeedFeature.address,
//      "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC as the input token
//      requiredUSDC,
//      admin.address, // tokens will be sent to the admin address
//      ethers.constants.AddressZero // No airdrop
//  );
//  await purchaseTx.wait();
//  const costForPurchase = await getTransactionCost(purchaseTx);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForPurchase));
//  let balanceAdmin0 = await vickAiERC20TokenSeedFeature.balanceOf(admin.address);
//  console.log(`                     -> Admin purchased ${balanceAdmin0} Vick-S tokens at a cost of: ${costForPurchase} ETH`);
    
//  const totalTokenSupply2 = await vickAiERC20TokenSeedFeature.balanceOf(admin.address) 
//  const approveTx4 = await vickAiERC20TokenSeedFeature.connect(admin).approve(dexAppFeature.address, totalTokenSupply2);
//  await approveTx4.wait();
//  const costForApproval4 = await getTransactionCost(approveTx4);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForApproval4));
//  console.log(`                   -> Approved ${totalTokenSupply2} VICK-S for DexApp at a cost of: ${costForApproval4} ETH`);

//  await _createPurchOrder(false, ethers.utils.parseUnits("836186.485", 18), ethers.utils.parseUnits("0.500000", 18), 0, admin); 
//  await _createPurchOrder(false, ethers.utils.parseUnits("736186.485", 18), ethers.utils.parseUnits("0.790000", 18), 0, admin); 
//  await _createPurchOrder(false, ethers.utils.parseUnits("100000.00", 18), ethers.utils.parseUnits("0.20000", 18), 0, admin).catch(error => {
//   console.log(`\n\n***** All tests OK ****`);
// });;

    // const WMaticContract = await ethers.getContractAt('IERC20', '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'); // The address of Wmatic
    // const approveWMATICTx2 = await WMaticContract.connect(admin).approve(vickAiERC20TokenSeedFeature.address, ethers.utils.parseEther('1000'));
    // await approveWMATICTx2.wait();
    // const costForApprovalWMATIC2 = await getTransactionCost(approveWMATICTx2);
    // totalCost = totalCost.add(ethers.utils.parseEther(costForApprovalWMATIC2));
    // console.log(`                     -> Approved DexApp ${ethers.utils.parseEther('10')} WMATIC a cost of: ${costForApprovalWMATIC2} ETH`);

 //Purchase 1000 Vick-S tokens using USDC from the Admin account
//  const purchaseTx = await dexAppFeature.connect(admin).swapToken(
//      gatewayId,
//      vickAiERC20TokenSeedFeature.address,
//      "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // USDC as the input token
//      ethers.utils.parseEther('1000'),
//      admin.address, // tokens will be sent to the admin address
//      ethers.constants.AddressZero // No airdrop
//  );
//  await purchaseTx.wait();
//  const costForPurchase = await getTransactionCost(purchaseTx);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForPurchase));
//  console.log(`                     -> Admin purchased 1000 Vick-S tokens at a cost of: ${costForPurchase} ETH`);


//   const swapTx = await dexAppFeature.connect(admin).swapNativeToken(gatewayId, vickAiERC20TokenSeedFeature.address, owner.address, {
//       value: ethers.utils.parseEther('4450')
//   });
//   await swapTx.wait();
  
//    const costForSwap = await getTransactionCost(swapTx);
//    totalCost = totalCost.add(ethers.utils.parseEther(costForSwap));
//    let balanceAdmin = await vickAiERC20TokenSeedFeature.balanceOf(admin.address);
//    console.log(`                   -> Swap ${ethers.utils.parseEther('4450')} Native to ${balanceAdmin - balanceAdmin0} VICK-S at a cost of: ${costForSwap} ETH`);

//    const swapTx2 = await dexAppFeature.connect(admin).swapNativeToken(gatewayId, vickAiERC20TokenSeedFeature.address, owner.address, {
//     value: ethers.utils.parseEther('4450')
// });
// await swapTx2.wait();

//  const costForSwap2 = await getTransactionCost(swapTx2);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForSwap2));
//  let balanceAdmin2 = await vickAiERC20TokenSeedFeature.balanceOf(admin.address);
//  console.log(`                   -> Swap ${ethers.utils.parseEther('4450')} Native to ${balanceAdmin2 - balanceAdmin - balanceAdmin0} VICK-S and indicate Owner to airdrop at a cost of: ${costForSwap2} ETH`);

//   console.log(`                     -> Vick seed USDC balance of: ${await USDCContract.balanceOf(addressVickAiSubdomain)}`);
//   balanceOwner = await vickAiERC20TokenSeedFeature.balanceOf(owner.address);
//   let diffBalanceOwner = balanceOwner - currentVickSOwnerBalance;
//   console.log(`                   -> Earned ${diffBalanceOwner} VICK-S at airdrop indication`);

//   const quotes = await dexAppFeature.connect(owner).getSwapQuote(gatewayId, "0xd6df932a45c0f255f85145f286ea0b292b21c90b", ethers.utils.parseEther('1000'));
//   if (!quotes || quotes.length === 0) {
//       throw new Error('No quotes returned');
//   }
//   const firstQuote = quotes[0];
//   console.log(`                     -> Quote: ${firstQuote.tokenInAmount} AAVE to ${firstQuote.tokenInAmount} Vick-S tokens at a cost of: ${costForPurchase} ETH`);

//  const AAVEContract = await ethers.getContractAt('ERC20', '0xd6df932a45c0f255f85145f286ea0b292b21c90b'); // AAVE
//  const approveTx3 = await AAVEContract.connect(owner).approve(vickAiERC20TokenSeedFeature.address, firstQuote.tokenInAmount);
//  await approveTx3.wait();
//  const costForApproval3 = await getTransactionCost(approveTx3);
//  totalCost = totalCost.add(ethers.utils.parseEther(costForApproval3));
//  console.log(`                     -> Approved DexApp to spend ${firstQuote.tokenInAmount} AAVE at a cost of: ${costForApproval3} ETH`);


//   const purchaseTx2 = await dexAppFeature.connect(owner).swapToken(
//     gatewayId,
//     vickAiERC20TokenSeedFeature.address,
//     "0xd6df932a45c0f255f85145f286ea0b292b21c90b", // AAVE as the input token
//     firstQuote.tokenInAmount,
//     owner.address, 
//     admin.address
// );


// await purchaseTx2.wait();
// const costForPurchase2 = await getTransactionCost(purchaseTx2);
// totalCost = totalCost.add(ethers.utils.parseEther(costForPurchase2));
// let balanceOwner0 = await vickAiERC20TokenSeedFeature.balanceOf(owner.address);
// console.log(`                     -> Owner purchased ${balanceOwner0 - balanceOwner} Vick-S tokens at a cost of: ${costForPurchase2} ETH`);

  

  console.log(`\n\nTotal cost for all transactions: ${ethers.utils.formatEther(totalCost)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.log(`\n\nTotal cost for all transactions: ${ethers.utils.formatEther(totalCost)} ETH`);
    console.error(error);
    process.exit(1);
  });
