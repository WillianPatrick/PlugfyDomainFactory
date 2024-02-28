const { latest } = require("@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time");
const { BigNumber } = require("ethers");
const { ethers, upgrades } = require("hardhat");
const { float } = require("hardhat/internal/core/params/argumentTypes");

  async function main() {

    const [owner] = await ethers.getSigners();
    console.log("Update contracts with the account:", owner.address);

    let nonce = await ethers.provider.getTransactionCount(owner.address, "latest");
    let gasPrice = await ethers.provider.getGasPrice();

    function getSelector(contract, functionName) {
      const signatures = Object.keys(contract.interface.functions);
      if (!signatures.includes(functionName)) {
          throw new Error(`Function ${functionName} does not exist on the contract.`);
      }

      return contract.interface.getSighash(functionName);
    }


  async function getTransactionCost(tx) {
      let receipt = null;
      while (receipt === null) {
          receipt = await ethers.provider.getTransactionReceipt(tx.hash);
          if (receipt === null) {
              await new Promise(resolve => setTimeout(resolve, 5000)); // espera 5 segundos antes de tentar novamente
          }
      }

      const cost = receipt.gasUsed.mul(tx.gasPrice);

    let latestNonce = await ethers.provider.getTransactionCount(owner.address, "latest");
    if(latestNonce > nonce)
      nonce = latestNonce;
    else
      nonce++;

    gasPrice = await ethers.provider.getGasPrice();

  }

  async function initializeFeature(contractName, functionName, contractAddress, args = []) {
    const contract = await ethers.getContractAt(contractName, contractAddress); // Mude 'Contract' para o nome real do seu contrato ou mantenha assim se for genérico
    if (!contract[functionName]) {
        throw new Error(`               -> ${contractName} - ${functionName} does not exist on the contract.`);
    }
  
    const tx = await contract[functionName](...args,{nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
    await tx.wait(1);
  
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
  }
  

  let extensibleFeatures = [...features];

  const featureManagerAppDomain = await ethers.getContractAt('FeatureManagerApp', "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  console.log(`Feature Manager App loaded on domain ${featureManagerAppDomain.address}`);

  //const dexAppDomain = await ethers.getContractAt('DexApp', "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //console.log(`DexApp loaded on domain ${featureManagerAppDomain.address}`);

  //const usdtContract = await ethers.getContractAt('ERC20', "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174");

  // const usdtContractApproveTx = await usdtContract.approve(featureManagerAppDomain.address, await usdtContract.balanceOf(owner.address), {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
  // console.log(`Aprove USDC balance for ${featureManagerAppDomain.address} = ${await usdtContract.balanceOf(owner.address)}`);
  // await getTransactionCost(usdtContractApproveTx);

  const ERC721URIStorageApp = await ethers.getContractFactory('ERC721URIStorageApp');
  const erc721URIStorageApp = await ERC721URIStorageApp.deploy({nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
  await getTransactionCost(await erc721URIStorageApp.deployTransaction);
  await erc721URIStorageApp.deployed();
  console.log(`Deploy new ERC721URIStorageApp contract on ${erc721URIStorageApp.address}`);

  const erc721URIStorageAppFunctionSelectors = getSelectors(erc721URIStorageApp);

    const erc721URIStorageAppFeatureArgs = {
        featureAddress: erc721URIStorageApp.address,
        action: 0, 
        functionSelectors: erc721URIStorageAppFunctionSelectors
    };

    extensibleFeatures.push(erc721URIStorageAppFeatureArgs);

    const vickAiArgs = {
      owner: owner.address,
      initAddress: ethers.constants.AddressZero,
      functionSelector: "0x00000000",
      initCalldata: '0x00'
``  };

  const vickAiDomainManagerFeature = await ethers.getContractAt('DomainManagerApp',  "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");

  const createDomainForNFT = await vickAiDomainManagerFeature.createDomain( "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "MKT Seed Campain 1 NFT Collection #1", extensibleFeatures, vickAiArgs, {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
  const ERC721URIStorageAppFeature = await ethers.getContractAt('ERC721URIStorageApp', createDomainForNFT.address);
  totalCost = totalCost.add(ethers.utils.parseEther(await initializeFeature('ERC721URIStorageApp','_initERC721URIStorage', ERC721URIStorageAppFeature.address, ["NFT.Vick.Ai Collection #1", "VKN1", `http://nft.vick.ai/${createDomainForNFT.address}/image`, 10000 ** 18, owner.address])));
//string memory _name, string memory _symbol, string memory _baseURI, uint256 _initialSupply, address _initialHolder

  // const featureManagerApp_Update = await featureManagerAppDomain.FeatureManager([[dexApp.address,1,[getSelector(dexApp, "swapTokenWithRouter(bytes32,address,address,address,uint256,address,address)"),getSelector(dexApp, "getSalesOrder(bytes32,address)")]],[dexApp.address,0,[getSelector(dexApp, "getSwapQuoteSalesToken(bytes32,address,address,uint256)")]]],"0x0000000000000000000000000000000000000000","0x00000000","0x00",false,{nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
  // //const featureManagerApp_Update = await featureManagerAppDomain.FeatureManager([[dexApp.address,1,[getSelector(dexApp, "swapTokenWithRouter(bytes32,address,address,address,uint256,address,address)"),getSelector(dexApp, "getSalesOrder(bytes32,address)"), getSelector(dexApp, "getSwapQuoteSalesToken(bytes32,address,address,uint256)")]]],"0x0000000000000000000000000000000000000000","0x00000000","0x00",false,{nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});

  // await getTransactionCost(featureManagerApp_Update);
  // console.log(`DexApp update methods getSwapQuoteSalesToken, swapTokenWithRouter, getSalesOrder`);

  //   async function logDex(){
  //     currentOrder = await dexAppDomain.getCurrentOrder("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //     totalShellOfferTokens = await dexAppDomain.totalShellOfferTokens("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //     totalCapAcceptedToken = await dexAppDomain.totalCapAcceptedToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //     getAirdropBalance = await dexAppDomain.getAirdropBalance("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //     getSalesOrder = await dexAppDomain.getSalesOrder("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");

  //     console.log("");
  //     console.log("- State -");
  //     console.log(`- Current Order Index: ${currentOrder} - Total Amount Offer Tokens: ${totalShellOfferTokens} - Total Cap Accepted Token: ${totalCapAcceptedToken}`);
  //     console.log(`- Airdrop balance: ${(getAirdropBalance)} - Current Sales Order Amount: ${getSalesOrder.amount} - Current Sales Order Price: ${getSalesOrder.price}`);
  //     console.log(`- Current Sales Order Burned on close: ${getSalesOrder.burnTokensClose}`);
      
  //     const vickERC20 = await ethers.getContractAt('ERC20', "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0");
  //     console.log(`- Balance of ${owner.address}: ${await vickERC20.balanceOf(owner.address)}`);
  //     console.log(`- Balance of 0x0F884EB5f6C96E524af72B7b68E34B73B73Da411: ${await vickERC20.balanceOf("0x0F884EB5f6C96E524af72B7b68E34B73B73Da411")}`);
      

  //     console.log("");
  //   }

  //   await logDex();

  //   async function test(value){
  //     let getSwapQuoteSalesToken = await dexAppDomain.getSwapQuoteSalesToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", value);
  //     console.log(`DexApp Quote SwapToken ${value} USDC = ${getSwapQuoteSalesToken.salesTokenAmount } VICK-S`);
  //     let dexAppTokenSwapTest = await dexAppDomain.swapToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", value, owner.address, "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411", {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
  //     await getTransactionCost(dexAppTokenSwapTest);
  //     console.log(`DexApp SwapToken test value ${value} executed on tx: ${await dexAppTokenSwapTest.hash}`);



  //     await logDex();
  //   }


  //     await test(133333333)
  //     await test(666666666)
  //     await test(999999999)
    //  await test(66666666666);
    //  await test(155555555555);
    //  await test(155555555555);
    //  await test(155555555555);

    //await logDex();
    //const dexAppTokenSwapTest2 = await dexAppDomain.swapToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 66666666666, owner.address, "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411", {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
    //await getTransactionCost(dexAppTokenSwapTest2);
    //console.log(`DexApp SwapToken test 2 executed: ${await dexAppTokenSwapTest2.hash}`);

    //await logDex();
    // let dexAppTokenSwapTest3 = await dexAppDomain.swapToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 99999999999, owner.address, "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411", {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
    // await getTransactionCost(dexAppTokenSwapTest3);
    // console.log(`DexApp SwapToken test 3 executed: ${await dexAppTokenSwapTest3.hash}`);

  
    // await logDex();
    // let dexAppTokenSwapTest4 = await dexAppDomain.swapToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 222222222222, owner.address, "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411", {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
    // await getTransactionCost(dexAppTokenSwapTest4);
    // console.log(`DexApp SwapToken test 4 executed: ${await dexAppTokenSwapTest4.hash}`);

    // await logDex();
    // let dexAppTokenSwapTest5 = await dexAppDomain.swapToken("0xb354633672df32a961a9fe34fcadb80ba3cb2a13437d53f9cfe59880d43579ee", "0x902f155886F60c8AdA2478edd92DCa56A1f5f3A0", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 555555555555, owner.address, "0x0F884EB5f6C96E524af72B7b68E34B73B73Da411", {nonce: nonce, gasPrice: gasPrice.add(ethers.utils.parseUnits("10", "gwei"))});
    // await getTransactionCost(dexAppTokenSwapTest5);
    // console.log(`DexApp SwapToken test 5 executed: ${await dexAppTokenSwapTest5.hash}`);
    //await logDex();

  }
  
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
