import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as mocha from "mocha-steps";
import { parseEther } from '@ethersproject/units';
import { FeatureManagerApp, FeatureRoutesApp, OwnershipApp, AdminApp } from '../typechain-types'; //ERC20ConstantsFeature, ERC20Feature, BalancesFeature,AllowancesFeature, SupplyRegulatorFeature,
import { assert } from 'chai';
import { getSelectors, getFunctionSignature } from "../scripts/libraries/domain";

describe("Domain Global Test", async () => {
    let featureManagerFeature: FeatureManagerApp;
    let featureRouterFeature: FeatureRoutesApp;
    let ownershipFeature: OwnershipApp;
    // let constantsFeature: ERC20ConstantsFeature;
    // let erc20Feature: ERC20Feature;
    // let balancesFeature: BalancesFeature;
    // let allowancesFeature: AllowancesFeature;
    // let supplyRegulatorFeature: SupplyRegulatorFeature;
    let adminFeature: AdminApp;

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

    let totalSupply = parseEther('2500000');
    let transferAmount = parseEther('1000');
    let name = "Token Name";
    let symbol = "SYMBOL";
    let decimals = 18;

    beforeEach(async () => {
        [owner, admin, user1, user2, user3] = await ethers.getSigners();
    });

    enum FeatureAction {
        Add,
        Replace,
        Remove
    }

    let calldataAfterDeploy: string;
    let addressDomain: string;

    let featureToAddressImplementation: FeatureToAddress = {};

    let features: Feature[] = [];

    const FeatureNames = [
        'FeatureManagerApp',
        'FeatureRoutesApp',
        'OwnershipApp'
    ];
    mocha.step("Deploy the mandatory features to service the Domain", async function() {
        for (const FeatureName of FeatureNames) {
            const Feature = await ethers.getContractFactory(FeatureName)
            const feature = await Feature.deploy()
            await feature.deployed();
            features.push({
              featureAddress: feature.address,
              action: FeatureAction.Add,
              functionSelectors: getSelectors(feature)
            });
            featureToAddressImplementation[FeatureName] = feature.address;
        };
    });
    
    mocha.step("Deploy the Domain contract", async function () {
        const domainArgs = {
            owner: owner.address,
            init: ethers.constants.AddressZero,
            initCalldata: '0x00'
        };
        const Domain = await ethers.getContractFactory('Domain')
        const domain = await Domain.deploy(ethers.constants.AddressZero,"Main Domain", features, domainArgs)
        await domain.deployed();
        addressDomain = domain.address;
    });

    mocha.step("Initialization of service contracts", async function () {
        featureManagerFeature = await ethers.getContractAt('FeatureManagerApp', addressDomain);
        featureRouterFeature = await ethers.getContractAt('FeatureRoutesApp', addressDomain);
        ownershipFeature = await ethers.getContractAt('OwnershipApp', addressDomain);
    });

    mocha.step("Ensuring that the feature addresses on the contract match those obtained during the implementation deployment", async function () {
        const addresses = [];
        for (const address of await featureRouterFeature.featureAddresses()) {
            addresses.push(address)
        }
        assert.sameMembers(Object.values(featureToAddressImplementation), addresses)
    });

    mocha.step("Get function selectors by their feature addresses", async function () {
        let selectors = getSelectors(featureManagerFeature)
        let result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['FeatureManagerApp'])
       
        assert.sameMembers(result, selectors)
        selectors = getSelectors(featureRouterFeature)
        result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['FeatureRoutesApp'])

        assert.sameMembers(result, selectors)
        selectors = getSelectors(ownershipFeature)
        result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['OwnershipApp'])

        assert.sameMembers(result, selectors)
    });

    mocha.step("Get feature addresses by selectors related to these features", async function () {
        assert.equal(
            featureToAddressImplementation['FeatureManagerApp'],
            await featureRouterFeature.featureAddress("0x928b1d82") //featureManager(Feature[] calldata _featureManager, address _init, bytes calldata _calldata)
        )
        assert.equal(
            featureToAddressImplementation['FeatureRoutesApp'],
            await featureRouterFeature.featureAddress("0x7f27b0d6") // features()
        )
        assert.equal(
            featureToAddressImplementation['FeatureRoutesApp'],
            await featureRouterFeature.featureAddress("0x52e8931d") // featureFunctionSelectors(address _feature)
        )
        assert.equal(
            featureToAddressImplementation['OwnershipApp'],
            await featureRouterFeature.featureAddress("0x8da5cb5b") // transferOwnership(address _newOwner)
        )
    });

    mocha.step("Transfer the right to change implementations and back", async function () {
        await ownershipFeature.connect(owner).transferOwnership(admin.address);
        assert.equal(await ownershipFeature.owner(), admin.address);
        await ownershipFeature.connect(admin).transferOwnership(owner.address);
        assert.equal(await ownershipFeature.owner(), owner.address);
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

    mocha.step("Deploy the AdminApp contract", async function() {
        const AdminAppFactory = await ethers.getContractFactory("AdminApp");
        adminFeature = await AdminAppFactory.deploy();
        await adminFeature.deployed();
        featureToAddressImplementation['AdminApp'] = adminFeature.address;
    });
    
    mocha.step("Extract and Register AdminApp's public and external functions", async function() {
        if (!adminFeature) throw new Error("AdminApp not initialized");
        const featureForAdmin = [{
            featureAddress: adminFeature.address,
            action: FeatureAction.Add,
            functionSelectors: getSelectors(adminFeature)
        }];

        await featureManagerFeature.connect(owner).FeatureManager(featureForAdmin, ethers.constants.AddressZero, "0x00");
    });


    mocha.step("Testing AdminApp's functionalities", async function() {
        const DEFAULT_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DEFAULT_ADMIN_ROLE'));
        const dummyRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DUMMY_ROLE'));

        adminFeature = await ethers.getContractAt('AdminApp', addressDomain);
        // Grant the DEFAULT_ADMIN_ROLE to the owner
        await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, addressDomain);
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
