
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibDomain } from "../../../libraries/LibDomain.sol";
import { OwnershipApp } from "../AccessControl/OwnershipApp.sol";
import { AccessControlApp } from "../AccessControl/AccessControlApp.sol";
import { IFeatureManager } from "../FeatureManager/IFeatureManager.sol";
import { IAdminApp } from "../AccessControl/IAdminApp.sol";
import { IReentrancyGuardApp } from "../AccessControl/IReentrancyGuardApp.sol";
library LibFeatureStore {

    enum ResourceType {
        Domains,
        Features,
        Any
    }

    enum LayersType {
        Core, //0
        Provider, //1
        Distributor, //2
        Customer, //3
        User, //4
        Any //*
    }

    enum TargetType {
        Function,
        Feature,
        Bundle,
        Any
    }

    enum ChanelType {
        Public,
        Private,
        Any
    }

    enum DependencyType {
        REQUIRED,  // Must be present
        OPTIONAL,  // Can be present but not necessary
        EXCLUDE    // Must not be present
    }

    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("feature.store.standard.storage");

    struct Function {
        bytes32 id;
        address featureAddress;
        bytes4 functionSelector;
        string name;
        uint256 version;
        uint256 updateDateTime;
        address author;
        address owner;
        bool disabled;
        bytes32[] dependencies;
        LayersType layer;
        ChanelType chanel;
    }

    struct Dependence {
        bytes32 id;
        TargetType targetType;
        bytes32 target;
        uint256 minVersion;
        uint256 maxVersion;
        uint256 order;
        DependencyType dependencyType;
        bytes32[] dependencies;
        bool disabled;
    }

    struct Feature {
        bytes32 id;
        address featureAddress;
        bytes4[] functionSelectors;
        string name;
        uint256 version;
        uint256 updateDateTime;
        address author;
        address owner;
        bool disabled;
        bytes32[] dependencies;
        LayersType layer;
        ChanelType chanel;
        ResourceType resourceType;
    }

    struct BundleFeaturesFunctions {
        bytes32 id;
        bytes32[] functions;
        bytes32[] features;
        bytes32[] bundles;
        string name;
        uint256 version;
        uint256 updateDateTime;
        address author;
        address owner;
        bool disabled;
        LayersType layer;
        ChanelType chanel;
        ResourceType resourceType;
    }

    struct Storage {
        mapping(ChanelType => mapping(ResourceType => mapping(TargetType => mapping(LayersType => bytes32[])))) targetItems;
        mapping(bytes32 => Feature) addressFeature;
        mapping(bytes32 => Function) functions;
        mapping(bytes32 => Dependence) dependencies;
        mapping(bytes32 => BundleFeaturesFunctions) bundleFeaturesFunctions;
        bool initialized;
    }

    function domainStorage() internal pure returns (Storage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

contract FeatureStoreApp {
    using LibFeatureStore for LibFeatureStore.Storage;

    modifier onlyExistingFunction(bytes32 functionId) {
        require(LibFeatureStore.domainStorage().functions[functionId].id == functionId, "Function not found");
        _;
    }

    modifier onlyExistingFeature(bytes32 featureId) {
        require(LibFeatureStore.domainStorage().addressFeature[featureId].id == featureId, "Feature not found");
        _;
    }

    modifier onlyExistingBundle(bytes32 bundleId) {
        require(LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId].id == bundleId, "Bundle not found");
        _;
    }

    modifier onlyExistingDependence(bytes32 dependenceId) {
        require(LibFeatureStore.domainStorage().dependencies[dependenceId].id == dependenceId, "Dependence not found");
        _;
    }

    function _init() public {
        require(!LibFeatureStore.domainStorage().initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).grantRole(LibDomain.DEFAULT_ADMIN_ROLE, msg.sender);

        // Protecting the contract's functions from reentrancy attacks
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("addFunction(LibFeatureStore.Function)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("removeFunction(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("addFeature(LibFeatureStore.Feature)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("removeFeature(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("toggleFeatureDisabled(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("addBundle(LibFeatureStore.BundleFeaturesFunctions)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("removeBundle(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("toggleBundleDisabled(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("addDependence(LibFeatureStore.Dependence)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("removeDependence(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("toggleDependenceDisabled(bytes32)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("updateFunction(LibFeatureStore.Function)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("updateFeature(LibFeatureStore.Feature)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("updateBundle(LibFeatureStore.BundleFeaturesFunctions)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("updateDependence(LibFeatureStore.Dependence)"))), true);

        // Setting up roles for specific functions
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("addFunction(LibFeatureStore.Function)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("removeFunction(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("addFeature(LibFeatureStore.Feature)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("removeFeature(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("toggleFeatureDisabled(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("addBundle(LibFeatureStore.BundleFeaturesFunctions)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("removeBundle(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("toggleBundleDisabled(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("addDependence(LibFeatureStore.Dependence)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("removeDependence(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("toggleDependenceDisabled(bytes32)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("updateFunction(LibFeatureStore.Function)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("updateFeature(LibFeatureStore.Feature)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("updateBundle(LibFeatureStore.BundleFeaturesFunctions)"))), LibDomain.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("updateDependence(LibFeatureStore.Dependence)"))), LibDomain.DEFAULT_ADMIN_ROLE);

        LibFeatureStore.domainStorage().initialized = true;
    }


    function addFunction(LibFeatureStore.Function memory newFunction) external {
        LibFeatureStore.domainStorage().functions[newFunction.id] = newFunction;
    }

    function removeFunction(bytes32 functionId) external {
        delete LibFeatureStore.domainStorage().functions[functionId];
    }

    function addFeature(LibFeatureStore.Feature memory newFeature) external {
        LibFeatureStore.domainStorage().addressFeature[newFeature.id] = newFeature;
    }

    function removeFeature(bytes32 featureId) external {
        delete LibFeatureStore.domainStorage().addressFeature[featureId];
    }

    function toggleFeatureDisabled(bytes32 featureId) external {
        LibFeatureStore.domainStorage().addressFeature[featureId].disabled = !LibFeatureStore.domainStorage().addressFeature[featureId].disabled;
    }

    function addBundle(LibFeatureStore.BundleFeaturesFunctions memory newBundle) external {
        LibFeatureStore.domainStorage().bundleFeaturesFunctions[newBundle.id] = newBundle;
    }

    function removeBundle(bytes32 bundleId) external {
        delete LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId];
    }

    function toggleBundleDisabled(bytes32 bundleId) external {
        LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId].disabled = !LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId].disabled;
    }

    function addDependence(LibFeatureStore.Dependence memory newDependence) external {
        LibFeatureStore.domainStorage().dependencies[newDependence.id] = newDependence;
    }

    function removeDependence(bytes32 dependenceId) external {
        delete LibFeatureStore.domainStorage().dependencies[dependenceId];
    }

    function getFunction(bytes32 functionId) external view returns (LibFeatureStore.Function memory) {
        return LibFeatureStore.domainStorage().functions[functionId];
    }

    function getFeature(bytes32 featureId) external view returns (LibFeatureStore.Feature memory) {
        return LibFeatureStore.domainStorage().addressFeature[featureId];
    }

    function getBundle(bytes32 bundleId) external view returns (LibFeatureStore.BundleFeaturesFunctions memory) {
        return LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId];
    }

    function getDependence(bytes32 dependenceId) external view returns (LibFeatureStore.Dependence memory) {
        return LibFeatureStore.domainStorage().dependencies[dependenceId];
    }

    function toggleDependenceDisabled(bytes32 dependenceId) external {
        LibFeatureStore.domainStorage().dependencies[dependenceId].disabled = !LibFeatureStore.domainStorage().dependencies[dependenceId].disabled;
    }

    function updateFunction(LibFeatureStore.Function memory updatedFunction) external onlyExistingFunction(updatedFunction.id) {
        LibFeatureStore.domainStorage().functions[updatedFunction.id] = updatedFunction;
    }

    function updateFeature(LibFeatureStore.Feature memory updatedFeature) external onlyExistingFeature(updatedFeature.id) {
        LibFeatureStore.domainStorage().addressFeature[updatedFeature.id] = updatedFeature;
    }

    function updateBundle(LibFeatureStore.BundleFeaturesFunctions memory updatedBundle) external onlyExistingBundle(updatedBundle.id) {
        LibFeatureStore.domainStorage().bundleFeaturesFunctions[updatedBundle.id] = updatedBundle;
    }

    function updateDependence(LibFeatureStore.Dependence memory updatedDependence) external onlyExistingDependence(updatedDependence.id) {
        LibFeatureStore.domainStorage().dependencies[updatedDependence.id] = updatedDependence;
    }

    function getFeaturesByBundle(bytes32 bundleId) external view returns (IFeatureManager.Feature[] memory) {
        LibFeatureStore.BundleFeaturesFunctions memory bundle = LibFeatureStore.domainStorage().bundleFeaturesFunctions[bundleId];
        require(bundle.id == bundleId, "Bundle not found");

        IFeatureManager.Feature[] memory features = new IFeatureManager.Feature[](bundle.features.length);
        for (uint256 i = 0; i < bundle.features.length; i++) {
            LibFeatureStore.Feature memory featureStoreFeature = LibFeatureStore.domainStorage().addressFeature[bundle.features[i]];
            features[i].featureAddress = featureStoreFeature.featureAddress;
            features[i].functionSelectors = featureStoreFeature.functionSelectors;
            features[i].action = IFeatureManager.FeatureManagerAction.Add;
        }

        return features;
    }


}

