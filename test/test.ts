const { expect } = require("chai");
const { ethers } = require("hardhat");
const assert = require('assert');
const mocha = require("mocha-steps");
const { parseEther } = require('@ethersproject/units');
const { FeatureManagerApp, FeatureRoutesApp, OwnershipApp, AdminApp, FeatureStoreApp, DomainManagerApp, ERC20App } = require('../typechain-types');
const { getSelectors } = require("../scripts/libraries/domain");

describe("Domain Global Test", async () => {
    let featureStore: FeatureStoreApp;
    let featureStoreBase: FeatureStoreApp;
    let featureManagerFeature: FeatureManagerApp;
    let featureRouterFeature: FeatureRoutesApp;
    let ownershipFeature: OwnershipApp;
    let adminFeature: AdminApp;
    let domainManagerFeature: DomainManagerApp;
    let featureERC20App: ERC20App;


    interface domainArgs {
        owner: any,
        initAddress: any,
        functionSelector: any,
        initCalldata: any,
        initializeForce: boolean
    }
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
    interface FeatureInitArgs {
        [key: string]: domainArgs
    }

    let domain1;
    let domain2;
    let coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
    let featuresBundle;

    beforeEach(async () => {
        [owner, admin, user1, user2, user3] = await ethers.getSigners();
    });

    mocha.step("Deploy the FeatureStore", async function () {
        const FeatureStoreFactory = await ethers.getContractFactory('FeatureStoreApp');
        featureStoreBase = await FeatureStoreFactory.deploy();
        await featureStoreBase.deployed();
    });

    mocha.step("Create core bundle and add features to service FeaturesStore", async function () {
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
                layer: 0, //core
                chanel: 0, //public
                resourceType: 0 //any
            };

            // Register the deployed feature in the FeatureStore
            await featureStoreBase.addFeature(featureStruct);
            featureToAddressImplementation[FeatureName] = feature.address;
            console.log("       -> " + FeatureName + " - deployed");
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
            layer: 0, //core
            chanel: 0, //public
            resourceType: 0 //domain
        };

        await featureStoreBase.addBundle(coreBundle);
        
    });

    mocha.step("Deploy the Domain contract", async function () {
        const coreBundleId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['string'], ['Core']));
        const features = await featureStoreBase.getFeaturesByBundle(coreBundleId);
        let _args = {
            owner: owner.address,
            initAddress: ethers.constants.AddressZero,
            functionSelector: "0x00000000",
            initCalldata: '0x00',
            initializeForce: false
        };


        const Domain = await ethers.getContractFactory('Domain');
        const domain = await Domain.deploy(ethers.constants.AddressZero, "Main Domain", features, _args);
        await domain.deployed();
        addressDomain = domain.address;
        console.log("       -> at address: "+ addressDomain);
    });

    mocha.step("Initialization of service contracts", async function () {
        featureStore = await ethers.getContractAt('FeatureStoreApp', addressDomain);
        featureManagerFeature = await ethers.getContractAt('FeatureManagerApp', addressDomain);
        featureRouterFeature = await ethers.getContractAt('FeatureRoutesApp', addressDomain);
        ownershipFeature = await ethers.getContractAt('OwnershipApp', addressDomain);
        adminFeature = await ethers.getContractAt('AdminApp', addressDomain);
        domainManagerFeature = await ethers.getContractAt('DomainManagerApp', addressDomain);

    });

    mocha.step("Deploy the ERC20 Feature contract", async function () {
        const ERC20App = await ethers.getContractFactory('ERC20App');
        const erc20App = await ERC20App.deploy();
        await erc20App.deployed();

        const features = [{
            featureAddress: erc20App.address,
            action: FeatureAction.Add,
            functionSelectors: getSelectors(erc20App)
        }];
        await featureManagerFeature.connect(owner).FeatureManager(features, ethers.constants.AddressZero, "0x00000000", "0x00", false);
        featureERC20App = await ethers.getContractAt('ERC20App', addressDomain);
        featureToAddressImplementation['ERC20App'] = erc20App.address;
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

        selectors = getSelectors(featureERC20App);
        result = await featureRouterFeature.featureFunctionSelectors(featureToAddressImplementation['ERC20App']); //_init 0xe63ab1e9
        expect(result).to.have.members(selectors);
    });

    mocha.step("Get feature addresses by selectors related to these features", async function () {
        expect(featureToAddressImplementation['FeatureManagerApp']).to.equal(
            await featureRouterFeature.featureAddress("0xaa5ddfc9") //featureManager(Feature[] calldata _featureManager, address _init, bytes calldata _calldata)
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
    mocha.step("Test ERC20 Initialize", async function () {
        await featureERC20App._init("Token Name",
            "Token Symbol",
            2500000000000000000000000n,
            18
        );

        const name = await featureERC20App.connect(owner).name();
        expect(name).to.equal("Token Name");

        const symbol = await featureERC20App.connect(owner).symbol();
        expect(symbol).to.equal("Token Symbol");

        const decimals = await featureERC20App.connect(owner).decimals();
        expect(decimals).to.equal(18);
        const totalSupply = await featureERC20App.connect(owner).totalSupply();
        expect(totalSupply).to.equal(2500000000000000000000000n);
    });

    mocha.step("Test ERC20 Transfer", async function () {
        const transferAmount = 1000;
        await featureERC20App.connect(owner).transfer(user1.address, transferAmount);
        const addr1Balance = await featureERC20App.connect(owner).balanceOf(user1.address);
        expect(addr1Balance).to.equal(transferAmount);
    });

    mocha.step("Test ERC20 Approve and TransferFrom", async function () {
        const approveAmount = 500;
        await featureERC20App.connect(owner).approve(user1.address, approveAmount);
        await featureERC20App.connect(user1).transferFrom(owner.address, user2.address, approveAmount);
        const addr2Balance = await featureERC20App.connect(user2).balanceOf(user2.address);
        expect(addr2Balance).to.equal(approveAmount);
    });

    mocha.step("Test ERC20 Burn", async function () {
        const burnAmount = ethers.BigNumber.from("1000").mul(ethers.BigNumber.from("10").pow(18));
        await featureERC20App.connect(owner).burn(burnAmount);
        const totalSupplyAfterBurn = await featureERC20App.connect(owner).totalSupply();
        expect(totalSupplyAfterBurn).to.equal(ethers.BigNumber.from("2499000").mul(ethers.BigNumber.from("10").pow(18)));
    });

    mocha.step("Ensure unauthorized users cannot transfer ownership", async function () {
        try {
            await ownershipFeature.connect(user1).transferOwnership(admin.address);
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("NotContractOwner");
        }
    });

    mocha.step("Ensure unauthorized users cannot pause the domain", async function () {
        try {
            await adminFeature.connect(user1).pauseDomain();
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("AccessControl: sender does not have required role");
        }
    });

    mocha.step("Ensure ERC20 edge cases - zero transfer", async function () {
        try {
            await featureERC20App.connect(owner).transfer(user1.address, 0);
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("Transfer amount must be greater than zero");
        }
    });

    mocha.step("Ensure ERC20 edge cases - transfer more than balance", async function () {
        try {
            const excessiveAmount = ethers.BigNumber.from("10000000000000000000000000");
            await featureERC20App.connect(owner).transfer(user1.address, excessiveAmount);
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("transfer amount exceeds balance");
        }
    });

    mocha.step("Ensure correct events are emitted", async function () {
        const tx = await featureERC20App.connect(owner).transfer(user1.address, 1000);
        const receipt = await tx.wait();
        assert.equal(receipt.events?.length, 1);
        const log = receipt.events[0];
        assert.equal(log.event, "Transfer");
        assert.equal(log.args.from, owner.address);
        assert.equal(log.args.to, user1.address);
        assert.equal(log.args.value, 1000);
    });

    mocha.step("Ensure function visibility - try calling internal function", async function () {
        // Assuming `_internalFunction` is an internal function in one of your contracts
        try {
            await featureERC20App.connect(user1)._burn(user1.address, ethers.utils.parseEther("1.0"));
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("is not a function");
        }
    });

    mocha.step("Removing the OwnershipApp - Owner should make it immutable", async function () {
        featureManagerFeature = await ethers.getContractAt('FeatureManagerApp', addressDomain);
        ownershipFeature = await ethers.getContractAt('OwnershipApp', addressDomain);

        expect(await ownershipFeature.connect(owner).owner()).to.equal(owner.address);

        const featuresRemove = [{
            featureAddress: featureToAddressImplementation['OwnershipApp'],
            action: FeatureAction.Remove,
            functionSelectors: ['0xf2fde38b']
        }];
        await featureManagerFeature.connect(owner).FeatureManager(featuresRemove, ethers.constants.AddressZero, "0x00000000", "0x00", false);

        try {
            await ownershipFeature.connect(owner).Owner();
            assert.fail("Expected revert not received");
        } catch (error) {
            expect(error.message).to.contain("Owner is not a function");
        }

        const featuresAdd = [{
            featureAddress: featureToAddressImplementation['OwnershipApp'],
            action: FeatureAction.Add,
            functionSelectors: ['0xf2fde38b']
        }];
        await featureManagerFeature.connect(owner).FeatureManager(featuresAdd, ethers.constants.AddressZero, "0x00000000", "0x00", false);
        expect(await ownershipFeature.connect(owner).owner()).to.equal(owner.address);
    });



    async function testAdminAppFunctions(domainAddress: string = addressDomain) {
        const DEFAULT_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('DEFAULT_ADMIN_ROLE'));
        const PAUSER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('PAUSER_ROLE'));

        adminFeature = await ethers.getContractAt('AdminApp', domainAddress);
        ownershipFeature = await ethers.getContractAt('OwnershipApp', domainAddress);

        await describe("Admin App Functions Tests domain: " + domainAddress, async () => {

            mocha.step("Owner should be able to set the admin role for the DEFAULT_ADMIN_ROLE", async () => {
                await adminFeature.connect(owner).setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
            });

            mocha.step("Owner should be able to set the admin role for the PAUSER_ROLE", async () => {
                await adminFeature.connect(owner).setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
            });

            mocha.step("Should grant DEFAULT_ADMIN_ROLE to the owner", async () => {
                await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, domainAddress);
                await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, owner.address);
                await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, user1.address);
                await adminFeature.connect(user1).grantRole(DEFAULT_ADMIN_ROLE, admin.address);
            });

            mocha.step("Owner should be able to grant the PAUSER_ROLE to users", async () => {
                await adminFeature.connect(owner).grantRole(PAUSER_ROLE, user1.address);
                expect(await adminFeature.hasRole(PAUSER_ROLE, user1.address)).to.be.true;

                await adminFeature.connect(owner).grantRole(PAUSER_ROLE, user2.address);
                expect(await adminFeature.hasRole(PAUSER_ROLE, user2.address)).to.be.true;

                await adminFeature.connect(owner).grantRole(PAUSER_ROLE, user3.address);
                expect(await adminFeature.hasRole(PAUSER_ROLE, user3.address)).to.be.true;
            });

            mocha.step("Owner should be able to grant and revoke DEFAULT_ADMIN_ROLE to user1", async () => {
                await adminFeature.connect(owner).grantRole(DEFAULT_ADMIN_ROLE, user2.address);
                expect(await adminFeature.hasRole(DEFAULT_ADMIN_ROLE, user2.address)).to.be.true;

                await adminFeature.connect(owner).revokeRole(DEFAULT_ADMIN_ROLE, user2.address);
                expect(await adminFeature.hasRole(DEFAULT_ADMIN_ROLE, user2.address)).to.be.false;
            });

            mocha.step("Owner should be able to revoke PAUSER_ROLE from users", async () => {
                await adminFeature.connect(owner).revokeRole(PAUSER_ROLE, user3.address);
                expect(await adminFeature.hasRole(PAUSER_ROLE, user3.address)).to.be.false;
            });

            mocha.step("Owner should be able to pause and unpause the domain", async () => {
                await adminFeature.connect(owner).pauseDomain();

                try {
                    await ownershipFeature.connect(user1).owner();
                } catch (error) {
                    expect(error.message).to.contain("DomainControl: This domain is currently paused and is not in operation");
                }

                await adminFeature.connect(owner).unpauseDomain();
                expect(await ownershipFeature.connect(user1).owner()).to.equal(owner.address);
            });

            mocha.step("Owner should be able to pause and unpause features on domain", async () => {
                const _featureAddresses = [featureToAddressImplementation['OwnershipApp']];

                expect(await ownershipFeature.connect(user1).owner()).to.equal(owner.address);

                await adminFeature.connect(user1).pauseFeatures(_featureAddresses);

                try {
                    await ownershipFeature.connect(user1).owner();
                    assert.fail("Expected to revert, but the function succeeded");
                } catch (error) {
                    expect(error.message).to.contain("FeatureControl: This feature and functions are currently paused and not in operation");
                }

                await adminFeature.connect(user1).unpauseFeatures(_featureAddresses);

                expect(await ownershipFeature.connect(user1).owner()).to.equal(owner.address);
            });



        });
    }



    mocha.step("Testing AdminApp's functionalities", async function () { await testAdminAppFunctions(addressDomain); });

    mocha.step("Create two distinct domains with Domain Manager Feature", async function () {
        featuresBundle = await featureStoreBase.getFeaturesByBundle(coreBundleId);
        const domain1Args = {
            parentDomain: addressDomain,  // Assuming parent domain is addressDomain
            domainName: "Domain1",
            features: [],  // Assuming no features are added initially
            args: {
                owner: owner.address,
                initAddress: ethers.constants.AddressZero,
                functionSelector: "0x00000000",
                initCalldata: '0x00'
            }
        };
        const domain2Args = {
            parentDomain: addressDomain,
            domainName: "Domain2",
            features: [],
            args: {
                owner: owner.address,
                initAddress: ethers.constants.AddressZero,
                functionSelector: "0x00000000",
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

    mocha.step("Testing AdminApp's functionalities for each domain", async function () {
        await testAdminAppFunctions(domain1);
        await testAdminAppFunctions(domain2);
    });

    let subdomain1;
    let subdomain2;
    mocha.step("Create subdomains for each domain", async function () {
        const domain1Args = {
            parentDomain: domain1,  // Assuming parent domain is addressDomain
            domainName: "Subdomain1",
            features: [],  // Assuming no features are added initially
            args: {
                owner: owner.address,
                initAddress: ethers.constants.AddressZero,
                functionSelector: "0x00000000",
                initCalldata: '0x00'
            }
        };
        const domain2Args = {
            parentDomain: domain2,
            domainName: "Subdomain2",
            features: [],
            args: {
                owner: owner.address,
                initAddress: ethers.constants.AddressZero,
                functionSelector: "0x00000000",
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

    mocha.step("Testing AdminApp's functionalities for each subdomain", async function () {
        await testAdminAppFunctions(subdomain1);
        await testAdminAppFunctions(subdomain2);
    });
});
