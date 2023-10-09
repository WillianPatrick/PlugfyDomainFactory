const { expect } = require("chai");
const { ethers } = require("hardhat");
const assert = require('assert');
const mocha = require("mocha-steps");
const { parseEther } = require('@ethersproject/units');
const { FeatureManagerApp, FeatureRoutesApp, OwnershipApp, AdminApp, FeatureStoreApp, DomainManagerApp } = require('../typechain-types');
const { getSelectors } = require("../scripts/libraries/domain");

describe("Domain Global Test", async () => {
    let featureStore: FeatureStoreApp;
    let featureStoreBase: FeatureStoreApp;
    let featureManagerFeature: FeatureManagerApp;
    let featureRouterFeature: FeatureRoutesApp;
    let ownershipFeature: OwnershipApp;
    let adminFeature: AdminApp;
    let domainManagerFeature: DomainManagerApp;

    interface Feature {
        featureAddress: string,
        action: FeatureAction,
        functionSelectors: string[]
    }

    interface FeatureToAddress {
        [key: string]: string
    }

    //let domainInit: DomainInit;

    let owner: SignerWithAddress, admin: SignerWithAddress, 
    user1: SignerWithAddress, user2: SignerWithAddress, user3: SignerWithAddress;

    enum FeatureAction {
        Add,
        Replace,
        Remove
    }

    let addressDomain: string;

    let featureToAddressImplementation: FeatureToAddress = {};
    const FeatureNames = [
        'FeatureStoreApp',
        'FeatureManagerApp',
        'FeatureRoutesApp',
        'OwnershipApp',
        'AdminApp',
        'DomainManagerApp'
    ];

    
    let domain1;
    let domain2;
    let coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
    let featuresBundle;

    beforeEach(async () => {
        [owner, admin, user1, user2, user3] = await ethers.getSigners();
    });

    mocha.step("Deploy the FeatureStore", async function() {
        const FeatureStoreFactory = await ethers.getContractFactory('FeatureStoreApp');
        featureStoreBase = await FeatureStoreFactory.deploy();
        await featureStoreBase.deployed();
    });

    mocha.step("Create core bundle and add features to service FeaturesStore", async function() {
        let featureIds = [];
        
        // Deploying and registering each core feature
        for (const FeatureName of FeatureNames) {
            const Feature = await ethers.getContractFactory(FeatureName);
            const feature = await Feature.deploy();
            await feature.deployed();
    
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
                layer: 0,
                chanel: 0
            };
    
            // Register the deployed feature in the FeatureStore
            await featureStoreBase.addFeature(featureStruct);
            featureToAddressImplementation[FeatureName] = feature.address;
    
            featureIds.push(featureStruct.id);
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
            layer: 0,
            chanel: 0
        };
    
       
        // Registering the Core bundle in the FeatureStore
        await featureStoreBase.addBundle(coreBundle);
    });
    
    mocha.step("Deploy the Domain contract", async function() {
        const coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
        const features = await featureStoreBase.getFeaturesByBundle(coreBundleId);
        
        const domainArgs = {
            owner: owner.address,
            init: ethers.constants.AddressZero,
            initCalldata: '0x00'
        };

        const Domain = await ethers.getContractFactory('Domain');
        const domain = await Domain.deploy(ethers.constants.AddressZero, "Main Domain", features, domainArgs);
        await domain.deployed();
        addressDomain = domain.address;
    });
    

    mocha.step("Initialization of service contracts", async function () {
        featureStore = await ethers.getContractAt('FeatureStoreApp', addressDomain);
        featureManagerFeature = await ethers.getContractAt('FeatureManagerApp', addressDomain);
        featureRouterFeature = await ethers.getContractAt('FeatureRoutesApp', addressDomain);
        ownershipFeature = await ethers.getContractAt('OwnershipApp', addressDomain);
        adminFeature = await ethers.getContractAt('AdminApp', addressDomain);
        domainManagerFeature = await ethers.getContractAt('DomainManagerApp', addressDomain);
    });
    mocha.step("Ensuring that the feature addresses on the contract match those obtained during the implementation deployment", async function () {
        const addresses = [];
        for (const address of await featureRouterFeature.featureAddresses()) {
            addresses.push(address);
        }
        expect(Object.values(featureToAddressImplementation)).to.have.members(addresses);
    });

    mocha.step("Get function selectors by their feature addresses", async function () {
        let selectors = getSelectors(featureManagerFeature);
        let result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['FeatureManagerApp']);
       
        expect(result).to.have.members(selectors);
        selectors = getSelectors(featureRouterFeature);
        result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['FeatureRoutesApp']);

        expect(result).to.have.members(selectors);
        selectors = getSelectors(ownershipFeature);
        result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['OwnershipApp']);

        expect(result).to.have.members(selectors);
    });

    mocha.step("Get feature addresses by selectors related to these features", async function () {
        expect(featureToAddressImplementation['FeatureManagerApp']).to.equal(
            await featureRouterFeature.featureAddress("0x928b1d82") //featureManager(Feature[] calldata _featureManager, address _init, bytes calldata _calldata)
        );
        expect(featureToAddressImplementation['FeatureRoutesApp']).to.equal(
            await featureRouterFeature.featureAddress("0x7f27b0d6") // features()
        );
        expect(featureToAddressImplementation['FeatureRoutesApp']).to.equal(
            await featureRouterFeature.featureAddress("0x52e8931d") // featureFunctionSelectors(address _feature)
        );
        expect(featureToAddressImplementation['OwnershipApp']).to.equal(
            await featureRouterFeature.featureAddress("0x8da5cb5b") // transferOwnership(address _newOwner)
        );
    });

    mocha.step("Transfer the right to change implementations and back", async function () {
        await ownershipFeature.connect(owner).transferOwnership(admin.address);
        expect(await ownershipFeature.owner()).to.equal(admin.address);
        await ownershipFeature.connect(admin).transferOwnership(owner.address);
        expect(await ownershipFeature.owner()).to.equal(owner.address);
    });

    // ERC20:

    // mocha.step("Deploy the contract that initializes variable values for the functions name(), symbol(), etc. during the featureManager function call", async function() {
    //     const DomainInit = await ethers.getContractFactory('DomainInit');
    //     domainInit = await DomainInit.deploy();
    //     await domainInit.deployed();
    // });

    // mocha.step("Forming calldata that will be called from Domain via delegatecall to initialize variables during the featureManager function call", async function () {
    //     calldataAfterDeploy = domainInit.interface.encodeFunctionData('initERC20', [
    //         name,
    //         symbol,
    //         decimals,
    //         admin.address,
    //         totalSupply
    //     ]);
    //     console.log("       > Token: "+ name + " - Symbol: "+ symbol + " - Decimals: "+ decimals + " - Total Suply: "+ totalSupply + " - Admin: "+ admin.address);
    // });

    // mocha.step("Deploy implementation with constants", async function () {
    //     const ConstantsFeature = await ethers.getContractFactory("ERC20ConstantsFeature");
    //     const constantsFeature = await ConstantsFeature.deploy();
    //     constantsFeature.deployed();
    //     const features = [{
    //         featureAddress: constantsFeature.address,
    //         action: FeatureAction.Add,
    //         functionSelectors: getSelectors(constantsFeature)
    //     }];
    //     await featureManagerFeature.connect(owner).FeatureManager(features, domainInit.address, calldataAfterDeploy);
    //     featureToAddressImplementation['ERC20ConstantsFeature'] = constantsFeature.address;
    // });

    // mocha.step("Initialization of the implementation with constants", async function () {
    //     constantsFeature = await ethers.getContractAt('ERC20ConstantsFeature', addressDomain);
    // });

    // mocha.step("Checking for the presence of constants", async function () {
    //     assert.equal(await constantsFeature.name(), name);
    //     assert.equal(await constantsFeature.symbol(), symbol);
    //     assert.equal(await constantsFeature.decimals(), decimals);
    //     assert.equal(await constantsFeature.admin(), admin.address);
    // });

    // mocha.step("Deploying implementation with a transfer function", async function () {
    //     const BalancesFeature = await ethers.getContractFactory("BalancesFeature");
    //     const balancesFeature = await BalancesFeature.deploy();
    //     balancesFeature.deployed();
    //     const features = [{
    //         featureAddress: balancesFeature.address,
    //         action: FeatureAction.Add,
    //         functionSelectors: getSelectors(balancesFeature)
    //     }];
    //     await featureManagerFeature.connect(owner).FeatureManager(features, ethers.constants.AddressZero, "0x00");
    //     featureToAddressImplementation['BalancesFeature'] = balancesFeature.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer", async function () {
    //     balancesFeature = await ethers.getContractAt('BalancesFeature', addressDomain);
    // });

    // mocha.step("Checking the view function of the implementation with balances and transfer", async function () {
    //     expect(await balancesFeature.totalSupply()).to.be.equal(totalSupply);
    //     expect(await balancesFeature.balanceOf(admin.address)).to.be.equal(totalSupply);
    // });

    // mocha.step("Checking the transfer", async function () {
    //     await balancesFeature.connect(admin).transfer(user1.address, transferAmount);
    //     expect(await balancesFeature.balanceOf(admin.address)).to.be.equal(totalSupply.sub(transferAmount));
    //     expect(await balancesFeature.balanceOf(user1.address)).to.be.equal(transferAmount);
    //     await balancesFeature.connect(user1).transfer(admin.address, transferAmount);
    // });

    // mocha.step("Deploying the implementation with allowances", async function () {
    //     const AllowancesFeature = await ethers.getContractFactory("AllowancesFeature");
    //     const allowancesFeature = await AllowancesFeature.deploy();
    //     allowancesFeature.deployed();
    //     const features = [{
    //         featureAddress: allowancesFeature.address,
    //         action: FeatureAction.Add,
    //         functionSelectors: getSelectors(allowancesFeature)
    //     }];
    //     await featureManagerFeature.connect(owner).FeatureManager(features, ethers.constants.AddressZero, "0x00");
    //     featureToAddressImplementation['ERC20ConstantsFeature'] = allowancesFeature.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer allowance, featurerove, transferFrom...", async function () {
    //     allowancesFeature = await ethers.getContractAt('AllowancesFeature', addressDomain);
    // });

    // mocha.step("Testing the functions allowance, featurerove, transferFrom", async function () {
    //     expect(await allowancesFeature.allowance(admin.address, user1.address)).to.equal(0);
    //     const valueForFeaturerove = parseEther("100");
    //     const valueForTransfer = parseEther("30");
    //     await allowancesFeature.connect(admin).featurerove(user1.address, valueForFeaturerove);
    //     expect(await allowancesFeature.allowance(admin.address, user1.address)).to.equal(valueForFeaturerove);
    //     await allowancesFeature.connect(user1).transferFrom(admin.address, user2.address, valueForTransfer);
    //     expect(await balancesFeature.balanceOf(user2.address)).to.equal(valueForTransfer);
    //     expect(await balancesFeature.balanceOf(admin.address)).to.equal(totalSupply.sub(valueForTransfer));
    //     expect(await allowancesFeature.allowance(admin.address, user1.address)).to.equal(valueForFeaturerove.sub(valueForTransfer));
    // });

    // mocha.step("Deploying the implementation with mint and burn", async function () {
    //     const SupplyRegulatorFeature = await ethers.getContractFactory("SupplyRegulatorFeature");
    //     supplyRegulatorFeature = await SupplyRegulatorFeature.deploy();
    //     supplyRegulatorFeature.deployed();
    //     const features = [{
    //         featureAddress: supplyRegulatorFeature.address,
    //         action: FeatureAction.Add,
    //         functionSelectors: getSelectors(supplyRegulatorFeature)
    //     }];
    //     await featureManagerFeature.connect(owner).FeatureManager(features, ethers.constants.AddressZero, "0x00");
    //     featureToAddressImplementation['SupplyRegulatorFeature'] = supplyRegulatorFeature.address;
    // });

    // mocha.step("Initialization of the implementation with mint and burn functions", async function () {
    //     supplyRegulatorFeature = await ethers.getContractAt('SupplyRegulatorFeature', addressDomain);
    // });
    
    // mocha.step("Checking the mint and burn functions", async function () {
    //     const mintAmount = parseEther('1000');
    //     const burnAmount = parseEther('500');
    //     await supplyRegulatorFeature.connect(admin).mint(user3.address, mintAmount);
    //     expect(await balancesFeature.balanceOf(user3.address)).to.equal(mintAmount);
    //     expect(await balancesFeature.totalSupply()).to.be.equal(totalSupply.add(mintAmount));
    //     await supplyRegulatorFeature.connect(admin).burn(user3.address, burnAmount);
    //     expect(await balancesFeature.balanceOf(user3.address)).to.equal(mintAmount.sub(burnAmount));
    //     expect(await balancesFeature.totalSupply()).to.be.equal(totalSupply.add(mintAmount).sub(burnAmount));
    // });

    
    // mocha.step("Extract and Register AdminApp's public and external functions", async function() {
    //     if (!adminFeature) throw new Error("AdminApp not initialized");
    //     const featureForAdmin = [{
    //         featureAddress: adminFeature.address,
    //         action: FeatureAction.Add,
    //         functionSelectors: getSelectors(adminFeature)
    //     }];

    //     await featureManagerFeature.connect(owner).FeatureManager(featureForAdmin, ethers.constants.AddressZero, "0x00");
    // });

    async function testAdminAppFunctions(domainAddress: string = addressDomain) {
        const DEFAULT_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DEFAULT_ADMIN_ROLE'));
        const dummyRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DUMMY_ROLE'));

        adminFeature = await ethers.getContractAt('AdminApp', domainAddress);
        // Grant the DEFAULT_ADMIN_ROLE to the owner
        await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, domainAddress);
        await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, owner.address);

        // Now, the owner can set the admin role for the dummyRole
        await adminFeature.connect(owner).setRoleAdmin(dummyRole, DEFAULT_ADMIN_ROLE);
    
        // Now the owner can grant the dummyRole to user1
        await adminFeature.connect(owner).grantRole(dummyRole, user1.address);
        expect(await adminFeature.hasRole(dummyRole, user1.address)).to.be.true;

        await adminFeature.connect(owner).grantRole(dummyRole, user2.address);
        expect(await adminFeature.hasRole(dummyRole, user2.address)).to.be.true;
        
        await adminFeature.connect(owner).grantRole(dummyRole, user3.address);
        expect(await adminFeature.hasRole(dummyRole, user3.address)).to.be.true;        
    
        // Example: Grant a role to an address
        await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminFeature.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.true;

        // Revoke the role from the address
        await adminFeature.connect(owner).revokeRole(dummyRole, user1.address);
        expect(await adminFeature.hasRole(dummyRole, user1.address)).to.be.true;

        await adminFeature.connect(owner).revokeRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminFeature.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.false;   
        
        expect(await adminFeature.hasRole(dummyRole, user1.address)).to.be.false;        
    }

    mocha.step("Testing AdminApp's functionalities", async function(){ await testAdminAppFunctions(addressDomain); });

    mocha.step("Create two distinct domains with Domain Manager Feature", async function() {
        featuresBundle = await featureStoreBase.getFeaturesByBundle(coreBundleId);
        const domain1Args = {
            parentDomain: addressDomain,  // Assuming parent domain is addressDomain
            domainName: "Domain1",
            features: [],  // Assuming no features are added initially
            args: {
                owner: owner.address,
                init: ethers.constants.AddressZero,
                initCalldata: '0x00'
            }
        };
        const domain2Args = {
            parentDomain: addressDomain,
            domainName: "Domain2",
            features: [],
            args: {
                owner: owner.address,
                init: ethers.constants.AddressZero,
                initCalldata: '0x00'
            }
        };
    
        await domainManagerFeature.createDomain(domain1Args.parentDomain, domain1Args.domainName, featuresBundle, domain1Args.args);
        await domainManagerFeature.createDomain(domain2Args.parentDomain, domain2Args.domainName, featuresBundle, domain2Args.args);

        domain1 = await domainManagerFeature.getDomainAddress(0);
        domain2 = await domainManagerFeature.getDomainAddress(1);
        expect(domain1).to.exist;
        expect(domain2).to.exist;
        expect(domain1).to.not.equal(domain2);

    });
   
    mocha.step("Testing AdminApp's functionalities for each domain", async function() {
        await testAdminAppFunctions(domain1);
        await testAdminAppFunctions(domain2);
    });

    let subdomain1;
    let subdomain2;
    mocha.step("Create subdomains for each domain", async function() {
        const domain1Args = {
            parentDomain: domain1,  // Assuming parent domain is addressDomain
            domainName: "Subdomain1",
            features: [],  // Assuming no features are added initially
            args: {
                owner: owner.address,
                init: ethers.constants.AddressZero,
                initCalldata: '0x00'
            }
        };
        const domain2Args = {
            parentDomain: domain2,
            domainName: "Subdomain2",
            features: [],
            args: {
                owner: owner.address,
                init: ethers.constants.AddressZero,
                initCalldata: '0x00'
            }
        };

        domainManagerFeature = await ethers.getContractAt('DomainManagerApp', domain1);
        await domainManagerFeature.createDomain(domain1Args.parentDomain, domain1Args.domainName, featuresBundle, domain1Args.args);
        subdomain1 = await domainManagerFeature.getDomainAddress(0);

        domainManagerFeature = await ethers.getContractAt('DomainManagerApp', domain2);
        await domainManagerFeature.createDomain(domain2Args.parentDomain, domain2Args.domainName, featuresBundle, domain2Args.args);
        subdomain2 = await domainManagerFeature.getDomainAddress(0);
    
        expect(subdomain1).to.exist;
        expect(subdomain2).to.exist;
        expect(subdomain1).to.not.equal(subdomain2);
    });
    
    mocha.step("Testing AdminApp's functionalities for each subdomain", async function() {
        await testAdminAppFunctions(subdomain1);
        await testAdminAppFunctions(subdomain2);
    });

    
    mocha.step("Removing the featureManager function for further immutability", async function () {
        const features = [{
            featureAddress: ethers.constants.AddressZero,
            action: FeatureAction.Remove,
            functionSelectors: ['0x928b1d82'] //featureManager(Feature[] calldata _featureManager, address _init, bytes calldata _calldata)
        }];
        await featureManagerFeature.connect(owner).FeatureManager(features, ethers.constants.AddressZero, "0x00");
    });
        
});
