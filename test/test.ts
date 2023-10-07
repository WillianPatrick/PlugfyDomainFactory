import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as mocha from "mocha-steps";
import { parseEther } from '@ethersproject/units';
import { PackagerManagerApp, PackagerRoutesApp, OwnershipApp, AdminApp } from '../typechain-types'; //ERC20ConstantsPackager, ERC20Packager, BalancesPackager,AllowancesPackager, SupplyRegulatorPackager,
import { assert } from 'chai';
import { getSelectors, getFunctionSignature } from "../scripts/libraries/domain";

describe("Domain Global Test", async () => {
    let packManagerPackager: PackagerManagerApp;
    let packRouterPackager: PackagerRoutesApp;
    let ownershipPackager: OwnershipApp;
    // let constantsPackager: ERC20ConstantsPackager;
    // let erc20Packager: ERC20Packager;
    // let balancesPackager: BalancesPackager;
    // let allowancesPackager: AllowancesPackager;
    // let supplyRegulatorPackager: SupplyRegulatorPackager;
    let adminPackager: AdminApp;

    interface Packager {
        packAddress: string,
        action: PackagerAction,
        functionSelectors: string[]
    }

    interface PackagerToAddress {
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

    enum PackagerAction {
        Add,
        Replace,
        Remove
    }

    let calldataAfterDeploy: string;
    let addressDomain: string;

    let packToAddressImplementation: PackagerToAddress = {};

    let packs: Packager[] = [];

    const PackagerNames = [
        'PackagerManagerApp',
        'PackagerRoutesApp',
        'OwnershipApp'
    ];
    mocha.step("Deploy the mandatory packs to service the Domain", async function() {
        for (const PackagerName of PackagerNames) {
            const Packager = await ethers.getContractFactory(PackagerName)
            const pack = await Packager.deploy()
            await pack.deployed();
            packs.push({
              packAddress: pack.address,
              action: PackagerAction.Add,
              functionSelectors: getSelectors(pack)
            });
            packToAddressImplementation[PackagerName] = pack.address;
        };
    });
    
    mocha.step("Deploy the Domain contract", async function () {
        const domainArgs = {
            owner: owner.address,
            init: ethers.constants.AddressZero,
            initCalldata: '0x00'
        };
        const Domain = await ethers.getContractFactory('Domain')
        const domain = await Domain.deploy(packs, domainArgs)
        await domain.deployed();
        addressDomain = domain.address;
    });

    mocha.step("Initialization of service contracts", async function () {
        packManagerPackager = await ethers.getContractAt('PackagerManagerApp', addressDomain);
        packRouterPackager = await ethers.getContractAt('PackagerRoutesApp', addressDomain);
        ownershipPackager = await ethers.getContractAt('OwnershipApp', addressDomain);
    });

    mocha.step("Ensuring that the pack addresses on the contract match those obtained during the implementation deployment", async function () {
        const addresses = [];
        for (const address of await packRouterPackager.packAddresses()) {
            addresses.push(address)
        }
        assert.sameMembers(Object.values(packToAddressImplementation), addresses)
    });

    mocha.step("Get function selectors by their pack addresses", async function () {
        let selectors = getSelectors(packManagerPackager)
        let result = await packRouterPackager.packFunctionSelectors(packToAddressImplementation['PackagerManagerApp'])
        console.log(result);
        
        assert.sameMembers(result, selectors)
        selectors = getSelectors(packRouterPackager)
        result = await packRouterPackager.packFunctionSelectors(packToAddressImplementation['PackagerRoutesApp'])
        console.log(result);

        assert.sameMembers(result, selectors)
        selectors = getSelectors(ownershipPackager)
        result = await packRouterPackager.packFunctionSelectors(packToAddressImplementation['OwnershipApp'])
        console.log(result);

        assert.sameMembers(result, selectors)
    });

    mocha.step("Get pack addresses by selectors related to these packs", async function () {
        assert.equal(
            packToAddressImplementation['PackagerManagerApp'],
            await packRouterPackager.packAddress("0xca9565e7") //packManager(Packager[] calldata _packManager, address _init, bytes calldata _calldata)
        )
        assert.equal(
            packToAddressImplementation['PackagerRoutesApp'],
            await packRouterPackager.packAddress("0x7c4d60ba") // packs()
        )
        assert.equal(
            packToAddressImplementation['PackagerRoutesApp'],
            await packRouterPackager.packAddress("0x608b4295") // packFunctionSelectors(address _pack)
        )
        assert.equal(
            packToAddressImplementation['OwnershipApp'],
            await packRouterPackager.packAddress("0x8da5cb5b") // transferOwnership(address _newOwner)
        )
    });

    mocha.step("Transfer the right to change implementations and back", async function () {
        await ownershipPackager.connect(owner).transferOwnership(admin.address);
        assert.equal(await ownershipPackager.owner(), admin.address);
        await ownershipPackager.connect(admin).transferOwnership(owner.address);
        assert.equal(await ownershipPackager.owner(), owner.address);
    });

    // ERC20:

    // mocha.step("Deploy the contract that initializes variable values for the functions name(), symbol(), etc. during the packManager function call", async function() {
    //     const DomainInit = await ethers.getContractFactory('DomainInit');
    //     domainInit = await DomainInit.deploy();
    //     await domainInit.deployed();
    // });

    // mocha.step("Forming calldata that will be called from Domain via delegatecall to initialize variables during the packManager function call", async function () {
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
    //     const ConstantsPackager = await ethers.getContractFactory("ERC20ConstantsPackager");
    //     const constantsPackager = await ConstantsPackager.deploy();
    //     constantsPackager.deployed();
    //     const packs = [{
    //         packAddress: constantsPackager.address,
    //         action: PackagerAction.Add,
    //         functionSelectors: getSelectors(constantsPackager)
    //     }];
    //     await packManagerPackager.connect(owner).packagerManager(packs, domainInit.address, calldataAfterDeploy);
    //     packToAddressImplementation['ERC20ConstantsPackager'] = constantsPackager.address;
    // });

    // mocha.step("Initialization of the implementation with constants", async function () {
    //     constantsPackager = await ethers.getContractAt('ERC20ConstantsPackager', addressDomain);
    // });

    // mocha.step("Checking for the presence of constants", async function () {
    //     assert.equal(await constantsPackager.name(), name);
    //     assert.equal(await constantsPackager.symbol(), symbol);
    //     assert.equal(await constantsPackager.decimals(), decimals);
    //     assert.equal(await constantsPackager.admin(), admin.address);
    // });

    // mocha.step("Deploying implementation with a transfer function", async function () {
    //     const BalancesPackager = await ethers.getContractFactory("BalancesPackager");
    //     const balancesPackager = await BalancesPackager.deploy();
    //     balancesPackager.deployed();
    //     const packs = [{
    //         packAddress: balancesPackager.address,
    //         action: PackagerAction.Add,
    //         functionSelectors: getSelectors(balancesPackager)
    //     }];
    //     await packManagerPackager.connect(owner).packagerManager(packs, ethers.constants.AddressZero, "0x00");
    //     packToAddressImplementation['BalancesPackager'] = balancesPackager.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer", async function () {
    //     balancesPackager = await ethers.getContractAt('BalancesPackager', addressDomain);
    // });

    // mocha.step("Checking the view function of the implementation with balances and transfer", async function () {
    //     expect(await balancesPackager.totalSupply()).to.be.equal(totalSupply);
    //     expect(await balancesPackager.balanceOf(admin.address)).to.be.equal(totalSupply);
    // });

    // mocha.step("Checking the transfer", async function () {
    //     await balancesPackager.connect(admin).transfer(user1.address, transferAmount);
    //     expect(await balancesPackager.balanceOf(admin.address)).to.be.equal(totalSupply.sub(transferAmount));
    //     expect(await balancesPackager.balanceOf(user1.address)).to.be.equal(transferAmount);
    //     await balancesPackager.connect(user1).transfer(admin.address, transferAmount);
    // });

    // mocha.step("Deploying the implementation with allowances", async function () {
    //     const AllowancesPackager = await ethers.getContractFactory("AllowancesPackager");
    //     const allowancesPackager = await AllowancesPackager.deploy();
    //     allowancesPackager.deployed();
    //     const packs = [{
    //         packAddress: allowancesPackager.address,
    //         action: PackagerAction.Add,
    //         functionSelectors: getSelectors(allowancesPackager)
    //     }];
    //     await packManagerPackager.connect(owner).packagerManager(packs, ethers.constants.AddressZero, "0x00");
    //     packToAddressImplementation['ERC20ConstantsPackager'] = allowancesPackager.address;
    // });

    // mocha.step("Initialization of the implementation with balances and transfer allowance, packrove, transferFrom...", async function () {
    //     allowancesPackager = await ethers.getContractAt('AllowancesPackager', addressDomain);
    // });

    // mocha.step("Testing the functions allowance, packrove, transferFrom", async function () {
    //     expect(await allowancesPackager.allowance(admin.address, user1.address)).to.equal(0);
    //     const valueForPackagerrove = parseEther("100");
    //     const valueForTransfer = parseEther("30");
    //     await allowancesPackager.connect(admin).packrove(user1.address, valueForPackagerrove);
    //     expect(await allowancesPackager.allowance(admin.address, user1.address)).to.equal(valueForPackagerrove);
    //     await allowancesPackager.connect(user1).transferFrom(admin.address, user2.address, valueForTransfer);
    //     expect(await balancesPackager.balanceOf(user2.address)).to.equal(valueForTransfer);
    //     expect(await balancesPackager.balanceOf(admin.address)).to.equal(totalSupply.sub(valueForTransfer));
    //     expect(await allowancesPackager.allowance(admin.address, user1.address)).to.equal(valueForPackagerrove.sub(valueForTransfer));
    // });

    // mocha.step("Deploying the implementation with mint and burn", async function () {
    //     const SupplyRegulatorPackager = await ethers.getContractFactory("SupplyRegulatorPackager");
    //     supplyRegulatorPackager = await SupplyRegulatorPackager.deploy();
    //     supplyRegulatorPackager.deployed();
    //     const packs = [{
    //         packAddress: supplyRegulatorPackager.address,
    //         action: PackagerAction.Add,
    //         functionSelectors: getSelectors(supplyRegulatorPackager)
    //     }];
    //     await packManagerPackager.connect(owner).packagerManager(packs, ethers.constants.AddressZero, "0x00");
    //     packToAddressImplementation['SupplyRegulatorPackager'] = supplyRegulatorPackager.address;
    // });

    // mocha.step("Initialization of the implementation with mint and burn functions", async function () {
    //     supplyRegulatorPackager = await ethers.getContractAt('SupplyRegulatorPackager', addressDomain);
    // });
    
    // mocha.step("Checking the mint and burn functions", async function () {
    //     const mintAmount = parseEther('1000');
    //     const burnAmount = parseEther('500');
    //     await supplyRegulatorPackager.connect(admin).mint(user3.address, mintAmount);
    //     expect(await balancesPackager.balanceOf(user3.address)).to.equal(mintAmount);
    //     expect(await balancesPackager.totalSupply()).to.be.equal(totalSupply.add(mintAmount));
    //     await supplyRegulatorPackager.connect(admin).burn(user3.address, burnAmount);
    //     expect(await balancesPackager.balanceOf(user3.address)).to.equal(mintAmount.sub(burnAmount));
    //     expect(await balancesPackager.totalSupply()).to.be.equal(totalSupply.add(mintAmount).sub(burnAmount));
    // });

    mocha.step("Deploy the AdminApp contract", async function() {
        const AdminAppFactory = await ethers.getContractFactory("AdminApp");
        adminPackager = await AdminAppFactory.deploy();
        await adminPackager.deployed();
        packToAddressImplementation['AdminApp'] = adminPackager.address;
    });
    
    mocha.step("Extract and Register AdminApp's public and external functions", async function() {
        if (!adminPackager) throw new Error("AdminApp not initialized");
        const packForAdmin = [{
            packAddress: adminPackager.address,
            action: PackagerAction.Add,
            functionSelectors: getSelectors(adminPackager)
        }];

        await packManagerPackager.connect(owner).packagerManager(packForAdmin, ethers.constants.AddressZero, "0x00");
    });


    mocha.step("Testing AdminApp's functionalities", async function() {
        const DEFAULT_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DEFAULT_ADMIN_ROLE'));
        const dummyRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DUMMY_ROLE'));

        adminPackager = await ethers.getContractAt('AdminApp', addressDomain);
        // Grant the DEFAULT_ADMIN_ROLE to the owner
        await adminPackager.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, addressDomain);
        await adminPackager.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, owner.address);

        // Now, the owner can set the admin role for the dummyRole
        await adminPackager.connect(owner).setRoleAdmin(dummyRole, DEFAULT_ADMIN_ROLE);
    
        // Now the owner can grant the dummyRole to user1
        await adminPackager.connect(owner).grantRole(dummyRole, user1.address);
        expect(await adminPackager.hasRole(dummyRole, user1.address)).to.be.true;

        await adminPackager.connect(owner).grantRole(dummyRole, user2.address);
        expect(await adminPackager.hasRole(dummyRole, user2.address)).to.be.true;
        
        await adminPackager.connect(owner).grantRole(dummyRole, user3.address);
        expect(await adminPackager.hasRole(dummyRole, user3.address)).to.be.true;        
    
        // Example: Grant a role to an address
        await adminPackager.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminPackager.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.true;

        // Revoke the role from the address
        await adminPackager.connect(owner).revokeRole(dummyRole, user1.address);
        expect(await adminPackager.hasRole(dummyRole, user1.address)).to.be.true;

        await adminPackager.connect(owner).revokeRole(DEFAULT_ADMIN_ROLE, user1.address);
        expect(await adminPackager.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.false;   
        
        expect(await adminPackager.hasRole(dummyRole, user1.address)).to.be.false;        
    });

    mocha.step("Removing the packManager function for further immutability", async function () {
        const packs = [{
            packAddress: ethers.constants.AddressZero,
            action: PackagerAction.Remove,
            functionSelectors: ['0xca9565e7'] //packManager(Packager[] calldata _packManager, address _init, bytes calldata _calldata)
        }];
        await packManagerPackager.connect(owner).packagerManager(packs, ethers.constants.AddressZero, "0x00");
    });
        
});
