import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as mocha from "mocha-steps";
import { parseEther } from '@ethersproject/units';
import { DomainInit, AppManagerApp, AppManagerViewerApp, OwnershipApp, AdminApp } from '../typechain-types'; //ERC20ConstantsApp, ERC20App, BalancesApp,AllowancesApp, SupplyRegulatorApp,
import { assert } from 'chai';
import { getSelectors, getFunctionSignature } from "../scripts/libraries/domain";

describe("Domain Global Test", async () => {
    let appManagerApp: AppManagerApp;
    let domainLoupeApp: AppManagerViewerApp;
    let ownershipApp: OwnershipApp;
    // let constantsApp: ERC20ConstantsApp;
    // let erc20App: ERC20App;
    // let balancesApp: BalancesApp;
    // let allowancesApp: AllowancesApp;
    // let supplyRegulatorApp: SupplyRegulatorApp;
    let adminApp: AdminApp;

    interface App {
        appAddress: string,
        action: AppAction,
        functionSelectors: string[]
    }

    interface AppToAddress {
        [key: string]: string
    }

    let domainInit: DomainInit;

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

    enum AppAction {
        Add,
        Replace,
        Remove
    }

    let calldataAfterDeploy: string;
    let addressDomain: string;

    let appToAddressImplementation: AppToAddress = {};

    let apps: App[] = [];

    const AppNames = [
        'AppManagerApp',
        'AppManagerViewerApp',
        'OwnershipApp'
    ];
    mocha.step("Deploy the mandatory apps to service the Domain", async function() {
        for (const AppName of AppNames) {
            const App = await ethers.getContractFactory(AppName)
            const app = await App.deploy()
            await app.deployed();
            apps.push({
              appAddress: app.address,
              action: AppAction.Add,
              functionSelectors: getSelectors(app)
            });
            appToAddressImplementation[AppName] = app.address;
        };
    });
    
    mocha.step("Deploy the Domain contract", async function () {
        const domainArgs = {
            owner: owner.address,
            init: ethers.constants.AddressZero,
            initCalldata: '0x00'
        };
        const Domain = await ethers.getContractFactory('Domain')
        const domain = await Domain.deploy(apps, domainArgs)
        await domain.deployed();
        addressDomain = domain.address;
    });

    mocha.step("Initialization of service contracts", async function () {
        appManagerApp = await ethers.getContractAt('AppManagerApp', addressDomain);
        domainLoupeApp = await ethers.getContractAt('AppManagerViewerApp', addressDomain);
        ownershipApp = await ethers.getContractAt('OwnershipApp', addressDomain);
    });

    mocha.step("Ensuring that the app addresses on the contract match those obtained during the implementation deployment", async function () {
        const addresses = [];
        for (const address of await domainLoupeApp.appAddresses()) {
            addresses.push(address)
        }
        assert.sameMembers(Object.values(appToAddressImplementation), addresses)
    });

    mocha.step("Get function selectors by their app addresses", async function () {
        let selectors = getSelectors(appManagerApp)
        let result = await domainLoupeApp.appFunctionSelectors(appToAddressImplementation['AppManagerApp'])
        assert.sameMembers(result, selectors)
        selectors = getSelectors(domainLoupeApp)
        result = await domainLoupeApp.appFunctionSelectors(appToAddressImplementation['AppManagerViewerApp'])
        assert.sameMembers(result, selectors)
        selectors = getSelectors(ownershipApp)
        result = await domainLoupeApp.appFunctionSelectors(appToAddressImplementation['OwnershipApp'])
        assert.sameMembers(result, selectors)
    });

    mocha.step("Get app addresses by selectors related to these apps", async function () {
        assert.equal(
            appToAddressImplementation['AppManagerApp'],
            await domainLoupeApp.appAddress("0xa8d68dd7") //appManager(App[] calldata _appManager, address _init, bytes calldata _calldata)
        )
        assert.equal(
            appToAddressImplementation['AppManagerViewerApp'],
            await domainLoupeApp.appAddress("0xec74dbec") // apps()
        )
        assert.equal(
            appToAddressImplementation['AppManagerViewerApp'],
            await domainLoupeApp.appAddress("0x7f7cb9e9") // appFunctionSelectors(address _app)
        )
        assert.equal(
            appToAddressImplementation['OwnershipApp'],
            await domainLoupeApp.appAddress("0x8da5cb5b") // transferOwnership(address _newOwner)
        )
    });

    mocha.step("Transfer the right to change implementations and back", async function () {
        await ownershipApp.connect(owner).transferOwnership(admin.address);
        assert.equal(await ownershipApp.owner(), admin.address);
        await ownershipApp.connect(admin).transferOwnership(owner.address);
        assert.equal(await ownershipApp.owner(), owner.address);
    });

    // ERC20:

    // mocha.step("Deploy the contract that initializes variable values for the functions name(), symbol(), etc. during the appManager function call", async function() {
    //     const DomainInit = await ethers.getContractFactory('DomainInit');
    //     domainInit = await DomainInit.deploy();
    //     await domainInit.deployed();
    // });

    // mocha.step("Forming calldata that will be called from Domain via delegatecall to initialize variables during the appManager function call", async function () {
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
    //     const ConstantsApp = await ethers.getContractFactory("ERC20ConstantsApp");
    //     const constantsApp = await ConstantsApp.deploy();
    //     constantsApp.deployed();
    //     const apps = [{
    //         appAddress: constantsApp.address,
    //         action: AppAction.Add,
    //         functionSelectors: getSelectors(constantsApp)
    //     }];
    //     await appManagerApp.connect(owner).appManager(apps, domainInit.address, calldataAfterDeploy);
    //     appToAddressImplementation['ERC20ConstantsApp'] = constantsApp.address;
    // });

    // mocha.step("Initialization of the implementation with constants", async function () {
    //     constantsApp = await ethers.getContractAt('ERC20ConstantsApp', addressDomain);
    // });

    // mocha.step("Checking for the presence of constants", async function () {
    //     assert.equal(await constantsApp.name(), name);
    //     assert.equal(await constantsApp.symbol(), symbol);
    //     assert.equal(await constantsApp.decimals(), decimals);
    //     assert.equal(await constantsApp.admin(), admin.address);
    // });

    // mocha.step("Deploying implementation with a transfer function", async function () {
    //     const BalancesApp = await ethers.getContractFactory("BalancesApp");
    //     const balancesApp = await BalancesApp.deploy();
    //     balancesApp.deployed();
    //     const apps = [{
    //         appAddress: balancesApp.address,
    //         action: AppAction.Add,
    //         functionSelectors: getSelectors(balancesApp)
    //     }];
    //     await appManagerApp.connect(owner).appManager(apps, ethers.constants.AddressZero, "0x00");
    //     appToAddressImplementation['BalancesApp'] = balancesApp.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer", async function () {
    //     balancesApp = await ethers.getContractAt('BalancesApp', addressDomain);
    // });

    // mocha.step("Checking the view function of the implementation with balances and transfer", async function () {
    //     expect(await balancesApp.totalSupply()).to.be.equal(totalSupply);
    //     expect(await balancesApp.balanceOf(admin.address)).to.be.equal(totalSupply);
    // });

    // mocha.step("Checking the transfer", async function () {
    //     await balancesApp.connect(admin).transfer(user1.address, transferAmount);
    //     expect(await balancesApp.balanceOf(admin.address)).to.be.equal(totalSupply.sub(transferAmount));
    //     expect(await balancesApp.balanceOf(user1.address)).to.be.equal(transferAmount);
    //     await balancesApp.connect(user1).transfer(admin.address, transferAmount);
    // });

    // mocha.step("Deploying the implementation with allowances", async function () {
    //     const AllowancesApp = await ethers.getContractFactory("AllowancesApp");
    //     const allowancesApp = await AllowancesApp.deploy();
    //     allowancesApp.deployed();
    //     const apps = [{
    //         appAddress: allowancesApp.address,
    //         action: AppAction.Add,
    //         functionSelectors: getSelectors(allowancesApp)
    //     }];
    //     await appManagerApp.connect(owner).appManager(apps, ethers.constants.AddressZero, "0x00");
    //     appToAddressImplementation['ERC20ConstantsApp'] = allowancesApp.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer allowance, approve, transferFrom...", async function () {
    //     allowancesApp = await ethers.getContractAt('AllowancesApp', addressDomain);
    // });

    // mocha.step("Testing the functions allowance, approve, transferFrom", async function () {
    //     expect(await allowancesApp.allowance(admin.address, user1.address)).to.equal(0);
    //     const valueForApprove = parseEther("100");
    //     const valueForTransfer = parseEther("30");
    //     await allowancesApp.connect(admin).approve(user1.address, valueForApprove);
    //     expect(await allowancesApp.allowance(admin.address, user1.address)).to.equal(valueForApprove);
    //     await allowancesApp.connect(user1).transferFrom(admin.address, user2.address, valueForTransfer);
    //     expect(await balancesApp.balanceOf(user2.address)).to.equal(valueForTransfer);
    //     expect(await balancesApp.balanceOf(admin.address)).to.equal(totalSupply.sub(valueForTransfer));
    //     expect(await allowancesApp.allowance(admin.address, user1.address)).to.equal(valueForApprove.sub(valueForTransfer));
    // });

    // mocha.step("Deploying the implementation with mint and burn", async function () {
    //     const SupplyRegulatorApp = await ethers.getContractFactory("SupplyRegulatorApp");
    //     supplyRegulatorApp = await SupplyRegulatorApp.deploy();
    //     supplyRegulatorApp.deployed();
    //     const apps = [{
    //         appAddress: supplyRegulatorApp.address,
    //         action: AppAction.Add,
    //         functionSelectors: getSelectors(supplyRegulatorApp)
    //     }];
    //     await appManagerApp.connect(owner).appManager(apps, ethers.constants.AddressZero, "0x00");
    //     appToAddressImplementation['SupplyRegulatorApp'] = supplyRegulatorApp.address;
    // });

    // mocha.step("Initialization of the implementation with mint and burn functions", async function () {
    //     supplyRegulatorApp = await ethers.getContractAt('SupplyRegulatorApp', addressDomain);
    // });
    
    // mocha.step("Checking the mint and burn functions", async function () {
    //     const mintAmount = parseEther('1000');
    //     const burnAmount = parseEther('500');
    //     await supplyRegulatorApp.connect(admin).mint(user3.address, mintAmount);
    //     expect(await balancesApp.balanceOf(user3.address)).to.equal(mintAmount);
    //     expect(await balancesApp.totalSupply()).to.be.equal(totalSupply.add(mintAmount));
    //     await supplyRegulatorApp.connect(admin).burn(user3.address, burnAmount);
    //     expect(await balancesApp.balanceOf(user3.address)).to.equal(mintAmount.sub(burnAmount));
    //     expect(await balancesApp.totalSupply()).to.be.equal(totalSupply.add(mintAmount).sub(burnAmount));
    // });

    mocha.step("Deploy the AdminApp contract", async function() {
        const AdminAppFactory = await ethers.getContractFactory("AdminApp");
        adminApp = await AdminAppFactory.deploy();
        await adminApp.deployed();
        appToAddressImplementation['AdminApp'] = adminApp.address;
    });
    
    mocha.step("Extract and Register AdminApp's public and external functions", async function() {
        if (!adminApp) throw new Error("AdminApp not initialized");
        const appForAdmin = [{
            appAddress: adminApp.address,
            action: AppAction.Add,
            functionSelectors: getSelectors(adminApp)
        }];

        await appManagerApp.connect(owner).appManager(appForAdmin, ethers.constants.AddressZero, "0x00");
    });


    mocha.step("Testing AdminApp's functionalities", async function() {
        const DEFAULT_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DEFAULT_ADMIN_ROLE'));
        const dummyRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DUMMY_ROLE'));

        adminApp = await ethers.getContractAt('AdminApp', addressDomain);
        // Grant the DEFAULT_ADMIN_ROLE to the owner
        await adminApp.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, addressDomain);
        await adminApp.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, owner.address);

        // Now, the owner can set the admin role for the dummyRole
        await adminApp.connect(owner).setRoleAdmin(dummyRole, DEFAULT_ADMIN_ROLE);
    
        // Now the owner can grant the dummyRole to user1
        await adminApp.connect(owner).grantRole(dummyRole, user1.address);
        expect(await adminApp.hasRole(dummyRole, user1.address)).to.be.true;

        await adminApp.connect(owner).grantRole(dummyRole, user2.address);
        expect(await adminApp.hasRole(dummyRole, user2.address)).to.be.true;
        
        await adminApp.connect(owner).grantRole(dummyRole, user3.address);
        expect(await adminApp.hasRole(dummyRole, user3.address)).to.be.true;        
    
        // Example: Grant a role to an address
        await adminApp.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminApp.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.true;

        // Revoke the role from the address
        await adminApp.connect(owner).revokeRole(dummyRole, user1.address);
        expect(await adminApp.hasRole(dummyRole, user1.address)).to.be.true;

        await adminApp.connect(owner).revokeRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminApp.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.false;   
        
        expect(await adminApp.hasRole(dummyRole, user1.address)).to.be.false;        
    });

    mocha.step("Removing the appManager function for further immutability", async function () {
        const apps = [{
            appAddress: ethers.constants.AddressZero,
            action: AppAction.Remove,
            functionSelectors: ['0xa8d68dd7'] //appManager(App[] calldata _appManager, address _init, bytes calldata _calldata)
        }];
        await appManagerApp.connect(owner).appManager(apps, ethers.constants.AddressZero, "0x00");
    });
        
});
