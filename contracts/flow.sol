// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// This token template enables a natural project flow, allowing seamless progress
// through milestones while adapting to real-world feedback. Created by YARRIVA.COM.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FlowToken is ERC20, Ownable, ReentrancyGuard {

    // --------------------- Constants & Configurations ---------------------
   
    // --------------------- Token Configuration ---------------------
    string private constant TOKEN_NAME = "FlowSol";  // Name of the token
    string private constant TOKEN_SYMBOL = "FLW";    // Symbol of the token
    string private constant TOKEN_IMAGE_URI = "https://yarriva.com/Projects/FlowSol/Images/coin.svg"; 

    // Versioning - Defines the current version of the smart contract
    uint256 private constant VERSION_MAJOR = 0;  // Major version (significant changes)
    uint256 private constant VERSION_MINOR = 1;  // Minor version (feature updates)
    uint256 private constant VERSION_PATCH = 68; // Patch version (small fixes or improvements)

    // Token Supply & Pricing
    uint256 internal constant INITIAL_SUPPLY = 360000 * (10 ** 18); // Total token supply for the entire project
    uint256 private constant MIN_TOKEN_PRICE_POL = 0.85 * (10 ** 18); // Minimum price of one token in ETH/BNB/POL ~0.25$

    // --------------------- Project Configuration ---------------------
    // Project Commitments & Milestone Descriptions
    string private constant PROJECT_COMMITMENT = 
        "Flow.Sol is committed to full transparency and open-source availability until version 1.0.0. "
        "Investor anonymity is maintained, except for blockchain addresses required for transactions. "
        "The smart contract ensures decentralized milestone tracking, with clear conditions for token "
        "distribution and project progress. Decisions regarding future project governance aim to be increasingly "
        "transferred to investors where applicable.";

    // --------------------- Milestone Configuration ---------------------
    uint256 private constant FIRST_MILESTONE_TOKENS = 90000 * (10 ** 18); // Token allocation for the first milestone (25% in this case from the total amount)
    string private constant FIRST_MILESTONE_NAME = "Contract Launch"; // Title of the first milestone
    uint256 private constant FIRST_MILESTONE_TOKEN_PRICE_POL = 2.72 * (10 ** 18); // 1 Token price in ETH/BNB/POL (depends on the chosen network) in this case for the first milestone ~0.5$
    string private constant FIRST_MILESTONE_DESC = 
        "Establishing the foundational process, developing the smart contract to support milestone-based funding, "
        "writing a comprehensive user guide covering deployment, usage, and governance, executing initial marketing "
        "efforts to attract early adopters, and designing the first version of the project's logo and branding elements.";

    // --------------------- Security Parameters ---------------------
    uint256 private constant INACTIVITY_THRESHOLD = 180 days; // If the owner is inactive for this period, ownership may be reassigned
    uint256 private constant MAX_ETH_PER_TX = 50 ether; // Maximum ETH that can be sent in a single transaction
    uint256 private constant MAX_TOKENS_PER_TX = 10000 * (10 ** 18); // Maximum number of tokens purchasable per transaction
    uint256 private constant MIN_PURCHASE_AMOUNT = 0.1 * (10 ** 18);// Minimum number of tokens purchasable per transaction
    
    // ----------------------------------------------------------------------------------

    // --------------------- Events ---------------------
    event VersionUpdated(string version, string updateNote);
    event ProjectStatusUpdated(ProjectStatus newStatus);
    event MilestoneUpdated(uint256 milestoneIndex, uint256 tokensAllocated, uint256 price);
    event OwnershipTransferredToInvestor(address newOwner);

    // --------------------- Enums & Structs ---------------------
    enum ProjectStatus { Active, Inactive, Completed, Archived }
    enum MilestoneStatus { Active, Inactive, Completed }

    struct Milestone {
        uint256 tokensAllocated;
        uint256 price;
        uint256 tokensPurchased;
        string title;
        string description;
        MilestoneStatus status;
    }

    struct TopInvestor {
        address investor;
        uint256 balance;
    }

    // --------------------- State Variables ---------------------
    ProjectStatus private projectStatus;
    mapping(uint256 => Milestone) private milestonesMap;
    uint256 private milestoneCount;
    uint256 private lastOwnerActivityTimestamp;
    TopInvestor[10] private topInvestors;
    mapping(address => uint8) private investorIndex; // 0 = not in list
    
    // --------------------- Constructor ---------------------
    constructor(address initialOwner) ERC20(TOKEN_NAME, TOKEN_SYMBOL) Ownable(initialOwner) {
        _mint(address(this), INITIAL_SUPPLY); // Mint the total supply to the contract itself

        // Initialize first milestone
        milestonesMap[0] = Milestone(
            FIRST_MILESTONE_TOKENS, // Token allocation
            FIRST_MILESTONE_TOKEN_PRICE_POL,        // Token price in ETH
            0,                          // Initial funding received
            FIRST_MILESTONE_NAME,      // Milestone title
            FIRST_MILESTONE_DESC,            // Milestone description
            MilestoneStatus.Active // Milestone status
        );

        milestoneCount++; // Increment milestone count
        lastOwnerActivityTimestamp = block.timestamp; // Track owner activity for inactivity checks
        projectStatus = ProjectStatus.Active; // Set initial status to Active
    }

    // --------------------- Modifiers ---------------------
    modifier onlyWhenActive() {
        require(projectStatus == ProjectStatus.Active, "Project is not active");
        _;
    }
    
    modifier checkOwnerActivity() {
        if (block.timestamp > lastOwnerActivityTimestamp + INACTIVITY_THRESHOLD) {
            projectStatus = ProjectStatus.Inactive;
            emit ProjectStatusUpdated(ProjectStatus.Inactive);
            address newOwner = topInvestors[0].investor;
            require(newOwner != address(0), "No eligible investor found for ownership transfer");
            _transferOwnership(newOwner);
            emit OwnershipTransferredToInvestor(newOwner);
        }
        _;
    }

    // --------------------- Core Functions ---------------------
    function buyCurrentOpenMilestoneTokens() public payable {
        require(msg.value > 0, "Error: You must send ETH to buy tokens.");
        require(msg.value <= MAX_ETH_PER_TX, "Transaction exceeds maximum ETH limit");

        uint256 activeMilestoneIndex = getActiveMilestone();
        require(activeMilestoneIndex < milestoneCount, "Error: No active milestone for purchase.");

        Milestone storage milestone = milestonesMap[activeMilestoneIndex];
        require(milestone.status == MilestoneStatus.Active, "Error: No active milestone for purchase.");

        uint256 tokensToBuy = (msg.value * (10 ** 18)) / milestone.price;
        //uint256 tokensToBuy = msg.value / milestone.price;
        require(tokensToBuy >= MIN_PURCHASE_AMOUNT, string.concat("Error: Payment too low to purchase tokens. msg.value:", Strings.toString(msg.value)));
        require(tokensToBuy <= (milestone.tokensAllocated - milestone.tokensPurchased), "Error: Not enough tokens available.");
        require(tokensToBuy <= MAX_TOKENS_PER_TX, "Cannot purchase more than allowed.");

        uint256 cost = ((tokensToBuy * milestone.price) + (10**18 - 1)) / (10**18);
        require(msg.value >= cost, "Error: Insufficient ETH sent.");
        uint256 excess = msg.value - cost;

        milestone.tokensPurchased += tokensToBuy;
        _transfer(address(this), msg.sender, tokensToBuy);

        updateTopInvestors(msg.sender, balanceOf(msg.sender));

        if (excess > 0) payable(msg.sender).transfer(excess);
    }

    /*
    * @param tokens Number of tokens allocated to this milestone.
    * @param price Price per token in Wei.
    * @param title A short title describing the milestone.
    * @param description A longer explanation of what the milestone covers.
    *
    * Example usage in Remix (Milesstone #2):
    * addMilestone(30000000000000000000000, 3264000000000000000, "Making token purchasing more accessible", "Making it possible to purchase tokens through third-party intermediaries at the click of a button using a credit card | Writing a guide to implementing this solution | Refining and improving the existing guide on the project page")
    */
    function addMilestone(uint256 tokensAllocated, uint256 price, string memory title, string memory description) public onlyOwner onlyWhenActive checkOwnerActivity {
        require(price >= MIN_TOKEN_PRICE_POL, "Price per token must be at least the minimum defined");
        milestonesMap[milestoneCount] = Milestone(tokensAllocated, price, 0, title, description, MilestoneStatus.Inactive);
        emit MilestoneUpdated(milestoneCount, tokensAllocated, price);
        milestoneCount++;
    }

    function getActiveMilestone() public view returns (uint256) {
        for (uint256 i = 0; i < milestoneCount; i++) {
            if (milestonesMap[i].status == MilestoneStatus.Active) return i;
        }
        return milestoneCount;
    }

    function getVersion() public pure returns (string memory) {
        return string(abi.encodePacked(Strings.toString(VERSION_MAJOR), ".", Strings.toString(VERSION_MINOR), ".", Strings.toString(VERSION_PATCH)));
    }

    function tokenURI() public pure returns (string memory) {
        return TOKEN_IMAGE_URI;
    }

    function updateOwnerLastActivity() public onlyOwner {
        lastOwnerActivityTimestamp = block.timestamp;
        if (projectStatus == ProjectStatus.Inactive) {
            projectStatus = ProjectStatus.Active; // Reactivate the project
            emit ProjectStatusUpdated(ProjectStatus.Active);
        }
    }

    function closeMilestone(uint256 milestoneIndex) internal {
        Milestone storage milestone = milestonesMap[milestoneIndex];
        require(milestone.status == MilestoneStatus.Active, "Milestone is not active");

        uint256 remainingTokens = milestone.tokensAllocated - milestone.tokensPurchased;

        _transfer(address(this), msg.sender, remainingTokens);
        milestone.status = MilestoneStatus.Completed;
        milestone.tokensPurchased = milestone.tokensAllocated;
    }

    function approveFinishMilestone(uint256 milestoneIndex) public onlyOwner onlyWhenActive checkOwnerActivity {
        uint256 activeMilestoneIndex = getActiveMilestone();
        require(milestoneIndex == activeMilestoneIndex, "Can only close the currently active milestone");

        closeMilestone(milestoneIndex);
    }

    function getOwnerStatus() public view returns (string memory) {
        uint256 inactivityPeriod = 90 days;
        uint256 timeSinceLastActivity = block.timestamp - lastOwnerActivityTimestamp;

        if (timeSinceLastActivity < inactivityPeriod) {
            return "Contract is active. Last owner activity was less than 3 months ago.";
        } else {
            uint256 timeUntilTokenDistribution = inactivityPeriod + INACTIVITY_THRESHOLD - timeSinceLastActivity;
            return string(abi.encodePacked("No activity for over 3 months. Remaining time until token distribution: ", uint2str(timeUntilTokenDistribution), " seconds."));
        }
    }

    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k--;
            bstr[k] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }

    // Get Functions
    function getInitialSupply() public pure returns (uint256) {
        return INITIAL_SUPPLY;
    }

    function getProjectStatus() public view returns (string memory) {
        if (projectStatus == ProjectStatus.Active) {
            return "Active. The project is currently active and ongoing.";
        } else if (projectStatus == ProjectStatus.Inactive) {
            return "Pause. The project is paused.";
        } else if (projectStatus == ProjectStatus.Completed) {
            return "Completed. The project has been successfully completed.";
        } else if (projectStatus == ProjectStatus.Archived) {
            return "Archived. The project is archived and no longer in development.";
        } else {
            return "Unknown: The project status is unknown.";
        }
    }

    function getProjectCommitment() public pure returns (string memory) {
        return PROJECT_COMMITMENT;
    }

    function getFirstMilestone() public pure returns (string memory) {
        return FIRST_MILESTONE_DESC;
    }

    function getMilestoneCount() public view returns (uint256) {
        return milestoneCount;
    }

    function getLastOwnerActivityTimestamp() public view returns (uint256) {
        return lastOwnerActivityTimestamp;
    }

    function setMilestoneStatus(uint256 milestoneIndex, MilestoneStatus newStatus) public onlyOwner onlyWhenActive {
        require(milestoneIndex < milestoneCount, "Invalid milestone index");
        require(newStatus == MilestoneStatus.Active || newStatus == MilestoneStatus.Inactive, "Invalid status");

        Milestone storage milestone = milestonesMap[milestoneIndex];

        require(milestone.status != MilestoneStatus.Completed, "Cannot change status of a completed milestone");

        milestone.status = newStatus;
    }

    function getMilestone(uint256 index) public view returns (
        uint256 tokensAllocated,
        uint256 price,
        uint256 tokensPurchased,
        string memory title,
        string memory description,
        MilestoneStatus status
    ) {
        require(index < milestoneCount, "Milestone does not exist");
        Milestone storage milestone = milestonesMap[index];
        return (
            milestone.tokensAllocated,
            milestone.price,
            milestone.tokensPurchased,
            milestone.title,
            milestone.description,
            milestone.status
        );
    }

    function updateMilestoneStatus(uint256 milestoneIndex, MilestoneStatus newStatus) public onlyOwner {
        require(milestoneIndex < milestoneCount, "Invalid milestone index");
        Milestone storage milestone = milestonesMap[milestoneIndex];

        require(milestone.status != MilestoneStatus.Completed, "Cannot change status of a completed milestone");
        require(newStatus != MilestoneStatus.Completed, "Cannot manually set milestone to Completed");

        milestone.status = newStatus;
    }

    function getInactivityThreshold() public pure returns (uint256) {
        return INACTIVITY_THRESHOLD;
    }

    function findTopInvestor() internal view returns (address) {
        address topInvestor = address(0);
        uint256 maxBalance = 0;

        for (uint8 i = 0; i < topInvestors.length; i++) {
            if (topInvestors[i].balance > maxBalance) {
                maxBalance = topInvestors[i].balance;
                topInvestor = topInvestors[i].investor;
            }
        }
        return topInvestor;
    }

    function updateTopInvestors(address investor, uint256 newBalance) internal {
        uint8 index = investorIndex[investor];

        if (index > 0) {
            // Already in list — update balance
            topInvestors[index - 1].balance = newBalance;
        } else {
            // Check if newBalance is higher than the lowest in the list
            uint8 lowestIndex = 0;
            uint256 lowestBalance = type(uint256).max;

            for (uint8 i = 0; i < topInvestors.length; i++) {
                if (topInvestors[i].balance < lowestBalance) {
                    lowestBalance = topInvestors[i].balance;
                    lowestIndex = i;
                }
            }

            if (newBalance > lowestBalance) {
                // Remove old entry from index mapping
                address removedInvestor = topInvestors[lowestIndex].investor;
                investorIndex[removedInvestor] = 0;

                // Replace with new one
                topInvestors[lowestIndex] = TopInvestor(investor, newBalance);
                investorIndex[investor] = lowestIndex + 1;
            } else {
                return; // Not enough to be in top 10
            }
        }

        // Optional: sort the array again descending by balance
        sortTopInvestors();
    }

    function sortTopInvestors() internal {
        for (uint8 i = 0; i < topInvestors.length; i++) {
            for (uint8 j = i + 1; j < topInvestors.length; j++) {
                if (topInvestors[j].balance > topInvestors[i].balance) {
                    // swap
                    TopInvestor memory temp = topInvestors[i];
                    topInvestors[i] = topInvestors[j];
                    topInvestors[j] = temp;

                    // update mapping
                    investorIndex[topInvestors[i].investor] = i + 1;
                    investorIndex[topInvestors[j].investor] = j + 1;
                }
            }
        }
    }
}