pragma solidity ^0.8.17;\n\n// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}\n\n// SPDX-License-Identifier: MIT


struct roleAccount {
    string name;
    bytes32 role;
    address account;
}
interface IAdminApp {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

    function getRoleHash32(string memory str) external pure returns (bytes32);
    function getRoleHash4(string memory str) external pure returns (bytes4);
    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role) external;

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function setFunctionRole(bytes4 functionSelector, bytes32 role) external;

    function removeFunctionRole(bytes4 functionSelector, bool noError) external;

    function pauseDomain() external;

    function unpauseDomain() external;

    function pauseFeatures(address[] memory _featureAddress) external;

    function unpauseFeatures(address[] memory _featureAddress) external;

}\n\n// SPDX-License-Identifier: MIT


interface IReentrancyGuardApp {


    function enableDisabledDomainReentrancyGuard(bool status) external;

    function enableDisabledFeatureReentrancyGuard(address feature, bool status) external;

    function enableDisabledFunctionReentrancyGuard(bytes4 functionSelector, bool status) external;

    function enableDisabledSenderReentrancyGuard(bool status) external;

    function isDomainReentrancyGuardEnabled() external view returns (bool);

    function isFeatureReentrancyGuardEnabled(address feature) external view returns (bool);

    function isFunctionReentrancyGuardEnabled(bytes4 functionSelector) external view returns (bool);

    function isSenderReentrancyGuardEnabled() external view returns (bool);    

    function getDomainLock() external view returns (uint256);

    function getFeatureLock(address feature) external view returns (uint256);

    function getFunctionLock(bytes4 functionSelector) external view returns (uint256);

    function getSenderLock(address sender) external view returns (uint256);    
   
}\n\n// SPDX-License-Identifier: MIT






library LibProposal {
    bytes32 constant PROPOSAL_STORAGE_POSITION = keccak256("proposal.feature.storage");

    enum ProposalStatus {
        PendingApproval,
        ApprovedForVoting,
        Rejected,
        Approved,
        Cancelled,
        Executed
    }

    struct ActionPlan {
        string description;
        uint256 budget;
        uint256 deliveryDate;
        bool fundsReleased;
    }

    struct Voter {
        bool hasVoted;
        bool vote;
    }

    struct Proposal {
        uint256 id;
        address tokenAddress;
        uint256 requiredAmount;
        address objective;
        address strategy;
        ActionPlan[] plans;
        uint256 totalBudget;
        uint256 releaseAmount;
        uint256 deadline;
        address proposer;
        ProposalStatus status;
        mapping(address => Voter) voters;
        uint256 yesVotes;
        uint256 noVotes;
        address payable fundingAddress;
        uint256 fundedAmount;
        uint256 reservedAmount;
        bool isFutureReserve;
    }

    struct ProposalStorage {
        mapping(uint256 => Proposal) proposals;
        uint256 proposalCount;
        bool initialized;
    }

    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }
}

contract ProposalApp {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant PROPOSAL_CREATOR_ROLE = keccak256("PROPOSAL_CREATOR_ROLE");
    bytes32 constant PROPOSAL_APPROVER_ROLE = keccak256("PROPOSAL_APPROVER_ROLE");
    bytes32 constant VOTING_MEMBER_ROLE = keccak256("VOTING_MEMBER_ROLE");
    bytes32 constant COUNCIL_ROLE = keccak256("COUNCIL_ROLE");

    using LibProposal for LibProposal.ProposalStorage;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event ProposalStatusChanged(uint256 indexed proposalId, LibProposal.ProposalStatus status);
    event Voted(uint256 indexed proposalId, address indexed voter, bool approve);
    event ProposalExecuted(uint256 indexed proposalId);
    event FundsReleasedForActionPlan(uint256 indexed proposalId, uint256 actionPlanIndex);

    function _initProposalApp() public {
        require(!LibProposal.proposalStorage().initialized, "Initialization has already been executed.");

        IAdminApp(address(this)).setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setRoleAdmin(PROPOSAL_CREATOR_ROLE, DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setRoleAdmin(PROPOSAL_APPROVER_ROLE, DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setRoleAdmin(VOTING_MEMBER_ROLE, DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setRoleAdmin(COUNCIL_ROLE, DEFAULT_ADMIN_ROLE);

        IAdminApp(address(this)).grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        IAdminApp(address(this)).grantRole(PROPOSAL_CREATOR_ROLE, msg.sender);
        IAdminApp(address(this)).grantRole(PROPOSAL_APPROVER_ROLE, msg.sender);
        IAdminApp(address(this)).grantRole(VOTING_MEMBER_ROLE, msg.sender);
        IAdminApp(address(this)).grantRole(COUNCIL_ROLE, msg.sender);        

        // Definindo funções específicas para funções
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initProposalFacet()"))), DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("createProposal(address,uint256,address,address,LibProposal.ActionPlan[],uint256,uint256,uint256,address payable,bool)"))), PROPOSAL_CREATOR_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("approveProposalForVoting(uint256)"))), PROPOSAL_APPROVER_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("rejectProposal(uint256)"))), PROPOSAL_APPROVER_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("voteOnProposal(uint256,bool)"))), VOTING_MEMBER_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("releaseFundsForActionPlan(uint256,uint256)"))), COUNCIL_ROLE);

        
        // Protegendo as funções do contrato de ataques de reentrância
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("createProposal(address,uint256,address,address,LibProposal.ActionPlan[],uint256,uint256,uint256,address payable,bool)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("voteOnProposal(uint256,bool)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("releaseFundsForActionPlan(uint256,uint256)"))), true);

        LibProposal.proposalStorage().initialized = true;
    }


    function createProposal(
        address tokenAddress,
        uint256 requiredAmount,
        address objective,
        address strategy,
        LibProposal.ActionPlan[] memory plans,
        uint256 totalBudget,
        uint256 releaseAmount,
        uint256 deadline,
        address payable fundingAddr,
        bool isFutureReserve
    ) public returns (uint256) {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();

        ps.proposalCount++;
        LibProposal.Proposal storage newProposal = ps.proposals[ps.proposalCount];

        newProposal.id = ps.proposalCount;
        newProposal.tokenAddress = tokenAddress;
        newProposal.requiredAmount = requiredAmount;
        newProposal.objective = objective;
        newProposal.strategy = strategy;
        for (uint i = 0; i < plans.length; i++) {
            newProposal.plans.push(plans[i]);
        }
        newProposal.totalBudget = totalBudget;
        newProposal.releaseAmount = releaseAmount;
        newProposal.deadline = deadline;
        newProposal.proposer = msg.sender;
        newProposal.status = LibProposal.ProposalStatus.PendingApproval;
        newProposal.fundingAddress = fundingAddr;
        newProposal.isFutureReserve = isFutureReserve;

        emit ProposalCreated(ps.proposalCount, msg.sender);
        return ps.proposalCount;
    }


    function approveProposalForVoting(uint256 proposalId) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];
        
        require(proposal.status == LibProposal.ProposalStatus.PendingApproval, "Proposal not in pending approval status");
        
        if (proposal.isFutureReserve) {
            IERC20 token = IERC20(proposal.tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            require(balance >= proposal.requiredAmount, "Insufficient token balance for this proposal");
            proposal.reservedAmount = proposal.requiredAmount;
        }

        proposal.status = LibProposal.ProposalStatus.ApprovedForVoting;
        emit ProposalStatusChanged(proposalId, LibProposal.ProposalStatus.ApprovedForVoting);
    }

    function rejectProposal(uint256 proposalId) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];
        
        require(proposal.status == LibProposal.ProposalStatus.PendingApproval, "Proposal not in pending approval status");

        proposal.status = LibProposal.ProposalStatus.Rejected;
        emit ProposalStatusChanged(proposalId, LibProposal.ProposalStatus.Rejected);
    }

    function cancelProposal(uint256 proposalId) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];
        
        require(proposal.status != LibProposal.ProposalStatus.Executed, "Executed proposals cannot be cancelled");
        require(proposal.proposer == msg.sender, "Only the proposer can cancel the proposal");

        proposal.status = LibProposal.ProposalStatus.Cancelled;
        emit ProposalStatusChanged(proposalId, LibProposal.ProposalStatus.Cancelled);
    }

    function voteOnProposal(uint256 proposalId, bool approve) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];
        
        require(proposal.status == LibProposal.ProposalStatus.ApprovedForVoting, "Proposal is not open for voting");
        require(!proposal.voters[msg.sender].hasVoted, "You have already voted on this proposal");
        
        proposal.voters[msg.sender].hasVoted = true;
        proposal.voters[msg.sender].vote = approve;

        if (approve) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }

        if (proposal.yesVotes > proposal.noVotes && proposal.status == LibProposal.ProposalStatus.ApprovedForVoting) {
            proposal.status = LibProposal.ProposalStatus.Approved;
            emit ProposalStatusChanged(proposalId, LibProposal.ProposalStatus.Approved);
        }
    }

    function releaseFundsForActionPlan(uint256 proposalId, uint256 actionPlanIndex) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];

        require(proposal.status == LibProposal.ProposalStatus.Approved, "Proposal not approved");
        require(!proposal.plans[actionPlanIndex].fundsReleased, "Funds already released for this action plan");

        IERC20 token = IERC20(proposal.tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        uint256 requiredFunds = proposal.plans[actionPlanIndex].budget;

        require(balance >= requiredFunds, "Insufficient token balance for this action plan");

        token.transfer(proposal.fundingAddress, requiredFunds);
        proposal.fundedAmount -= requiredFunds;
        proposal.plans[actionPlanIndex].fundsReleased = true;

        emit FundsReleasedForActionPlan(proposalId, actionPlanIndex);
    }

    function manualWithdraw(uint256 proposalId, uint256 amount) public {
        LibProposal.ProposalStorage storage ps = LibProposal.proposalStorage();
        LibProposal.Proposal storage proposal = ps.proposals[proposalId];
        
        require(proposal.isFutureReserve, "Not a future reserve proposal");
        require(proposal.status == LibProposal.ProposalStatus.Approved, "Proposal not approved");
        require(msg.sender == proposal.fundingAddress, "Only the funding address can withdraw");
        
        IERC20 token = IERC20(proposal.tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient token balance");
        require(proposal.reservedAmount >= amount, "Requested amount exceeds reserved amount");
        
        token.transfer(proposal.fundingAddress, amount);
        proposal.reservedAmount -= amount;
    }
}