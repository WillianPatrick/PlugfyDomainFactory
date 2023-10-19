// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LibDomain} from "./libraries/LibDomain.sol";
import {IFeatureManager} from "./apps/core/FeatureManager/IFeatureManager.sol";

struct DomainArgs {
    address owner;
    address initAddress;
    bytes4 functionSelector;
    bytes initCalldata;
    bool forceInitialize;
}

contract Domain {
    error ReentrancyGuardLock(uint256 domainLocks, uint256 featureLocks);

    constructor(
        address _parentDomain,
        string memory _domainName,
        IFeatureManager.Feature[] memory _featureManager,
        DomainArgs memory _args
    ) {
        LibDomain.setContractOwner(_args.owner);
        LibDomain.setSuperAdmin(address(msg.sender));
        LibDomain.domainStorage().parentDomain = _parentDomain;
        LibDomain.domainStorage().name = _domainName;
        LibDomain.featureManager(
            _featureManager,
            _args.initAddress,
            _args.functionSelector,
            _args.initCalldata,
            _args.forceInitialize
        );
    }

    fallback() external payable {
        delegateToFeature(msg.sig);
    }

    receive() external payable {
        bytes4 receiveSelector = bytes4(keccak256(bytes("receive()")));
        delegateToFeature(receiveSelector);
    }

    function delegateToFeature(bytes4 functionSelector) internal {
        LibDomain.DomainStorage storage ds = LibDomain.domainStorage();

        require(
            !ds.paused ||
                ds.superAdmin == msg.sender ||
                ds.contractOwner == msg.sender,
            "This domain is currently paused and is not in operation"
        );

        if (ds.functionRoles[functionSelector] != bytes32(0)) {
            require(
                ds.accessControl[ds.functionRoles[functionSelector]][
                    msg.sender
                ] ||
                    ds.superAdmin == msg.sender ||
                    ds.contractOwner == msg.sender,
                "Sender does not have access to this function"
            );
        }

        address feature = ds
            .featureAddressAndSelectorPosition[functionSelector]
            .featureAddress;
        if (feature == address(0)) {
            revert LibDomain.FunctionNotFound(functionSelector);
        }

        require(
            !ds.pausedFeatures[feature] ||
                ds.superAdmin == msg.sender ||
                ds.contractOwner == msg.sender,
            "This feature and functions are currently paused and not in operation"
        );

        bytes32 domainGuardKey = keccak256(
            abi.encodePacked("domainGlobalReentrancyGuardEnabled")
        );
        bytes32 featureGuardKey = keccak256(
            abi.encodePacked(feature, "featuresReentrancyGuardEnabled")
        );
        bytes32 functionGuardKey = keccak256(
            abi.encodePacked(
                functionSelector,
                "functionsReentrancyGuardEnabled"
            )
        );
        bytes32 senderGuardKey = keccak256(
            abi.encodePacked("senderReentrancyGuardEnabled")
        );

        bytes32 domainGuardLock = keccak256(
            abi.encodePacked("domainGlobalReentrancyGuardLock")
        );
        bytes32 featureGuardLock = keccak256(
            abi.encodePacked(feature, "featuresReentrancyGuardLock")
        );
        bytes32 functionGuardLock = keccak256(
            abi.encodePacked(functionSelector, "functionsReentrancyGuardLock")
        );
        bytes32 senderGuardLock = keccak256(
            abi.encodePacked(msg.sender, "senderReentrancyGuardLock")
        );

        bytes4 errorSelector = Domain.ReentrancyGuardLock.selector;
        assembly ("memory-safe") {
            let isDomainReentrancyGuardEnabled := sload(
                add(ds.slot, domainGuardKey)
            )
            let isFeatureReentrancyGuardEnabled := sload(
                add(ds.slot, featureGuardKey)
            )
            let isFunctionReentrancyGuardEnabled := sload(
                add(ds.slot, functionGuardKey)
            )
            let isSenderReentrancyGuardEnabled := sload(
                add(ds.slot, senderGuardKey)
            )

            let shouldLock := or(
                or(
                    or(
                        and(
                            isDomainReentrancyGuardEnabled,
                            isFunctionReentrancyGuardEnabled
                        ),
                        and(
                            isFeatureReentrancyGuardEnabled,
                            isFunctionReentrancyGuardEnabled
                        )
                    ),
                    and(
                        and(
                            isFunctionReentrancyGuardEnabled,
                            iszero(eq(isDomainReentrancyGuardEnabled, 1))
                        ),
                        iszero(eq(isFunctionReentrancyGuardEnabled, 1))
                    )
                ),
                isSenderReentrancyGuardEnabled
            )

            if shouldLock {
                if or(
                    or(
                        or(
                            and(
                                iszero(
                                    eq(sload(add(ds.slot, domainGuardLock)), 0)
                                ),
                                and(
                                    isDomainReentrancyGuardEnabled,
                                    isFunctionReentrancyGuardEnabled
                                )
                            ),
                            and(
                                iszero(
                                    eq(sload(add(ds.slot, featureGuardLock)), 0)
                                ),
                                and(
                                    isFeatureReentrancyGuardEnabled,
                                    and(
                                         iszero(isDomainReentrancyGuardEnabled),
                                         isFunctionReentrancyGuardEnabled
                                    )
                                )
                            )
                        ),
                        and(
                            iszero(
                                eq(sload(add(ds.slot, functionGuardLock)), 0)
                            ),
                            and(
                            isFunctionReentrancyGuardEnabled,
                                iszero(isFeatureReentrancyGuardEnabled)
                               )
                        )
                    ),
                    and(
                        isSenderReentrancyGuardEnabled,
                        iszero(eq(sload(add(ds.slot, senderGuardLock)), 0))
                    )
                ) {
                    let ptr := mload(0x40)
                    mstore(ptr, errorSelector)
                    mstore(add(ptr, 0x04), sload(add(ds.slot, domainGuardLock)))
                    mstore(
                        add(ptr, 0x24),
                        sload(add(ds.slot, featureGuardLock))
                    )
                    revert(ptr, 0x44)
                }
                if and(
                    isDomainReentrancyGuardEnabled,
                    isFunctionReentrancyGuardEnabled
                ) {
                    sstore(
                        add(ds.slot, domainGuardLock),
                        add(sload(add(ds.slot, domainGuardLock)), 1)
                    )
                }
                if and(
                    isFeatureReentrancyGuardEnabled,
                    isFunctionReentrancyGuardEnabled
                ) {
                    sstore(
                        add(ds.slot, featureGuardLock),
                        add(sload(add(ds.slot, featureGuardLock)), 1)
                    )
                }
                if isFunctionReentrancyGuardEnabled {
                    sstore(
                        add(ds.slot, functionGuardLock),
                        add(sload(add(ds.slot, functionGuardLock)), 1)
                    )
                }
                if isSenderReentrancyGuardEnabled {
                    sstore(
                        add(ds.slot, senderGuardLock),
                        add(sload(add(ds.slot, senderGuardLock)), 1)
                    )
                }
            }

            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), feature, 0, calldatasize(), 0, 0)

            if shouldLock {
                if and(
                    isDomainReentrancyGuardEnabled,
                    isFunctionReentrancyGuardEnabled
                ) {
                    sstore(add(ds.slot, domainGuardLock), sub(sload(add(ds.slot, domainGuardLock)), 1))
                }
                if and(
                    isFeatureReentrancyGuardEnabled,
                    isFunctionReentrancyGuardEnabled
                ) {
                    sstore(add(ds.slot, featureGuardLock), sub(sload(add(ds.slot, featureGuardLock)), 1))
                }
                if isFunctionReentrancyGuardEnabled {
                    sstore(add(ds.slot, functionGuardLock), sub(sload(add(ds.slot, functionGuardLock)), 1))
                }
                if isSenderReentrancyGuardEnabled {
                    sstore(
                        add(ds.slot, senderGuardLock),
                        sub(sload(add(ds.slot, senderGuardLock)), 1)
                    )
                }
            }

            let rSize := returndatasize()
            returndatacopy(0, 0, rSize)

            switch result
            case 0 {
                revert(0, rSize)
            }
            default {
                return(0, rSize)
            }
        }
    }
}
