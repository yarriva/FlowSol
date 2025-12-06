FlowSol - Milestone-Based Funding Token

FlowSol (FLW) is a transparent, open-source ERC-20 smart contract designed for project funding based on predefined milestones.
Each milestone has its own token allocation and price, allowing structured progress and clear accountability.

This repository contains the public source code of the deployed Flow.sol contract.

⸻

Overview

FlowSol enables a project to be funded in stages.
Investors purchase tokens at each milestone, providing both transparency and flexibility.
The contract stores all milestone definitions, pricing rules, supply limits, and investor safeguards directly on-chain.

⸻

Contract Details
	•	Token Name: FlowSol
	•	Symbol: FLW
	•	Total Supply: 360,000 FLW
	•	Standard: ERC-20
	•	Network: (add the network you deployed on)
	•	Initial Mint: Minted to the contract itself
	•	Milestone Purchase: Investors send native currency and receive FLW in return

⸻

Features

Milestone Structure
	•	Each milestone includes:
	•	Token allocation
	•	Token price
	•	Title and description
	•	Purchase tracking
	•	Status (Active, Inactive, Completed)

Purchase Logic
	•	Tokens are purchased directly from the contract
	•	Excess payments are automatically refunded
	•	Enforced limits:
	•	Maximum tokens per transaction
	•	Maximum ETH/POL/BNB per transaction
	•	Minimum purchase threshold

Ownership and Activity
	•	Owner activity is monitored
	•	If the owner is inactive for 180 days, ownership may automatically transfer to the top investor
	•	The owner can reactivate the project by registering activity

⸻

Repository Contents
	•	Flow.sol - main contract file

⸻

License

This project is released under the MIT License.
It is fully open for review, contribution, and reuse.

⸻

Contributing

Contributions, pull requests, and discussions are welcome.
You may also fork the contract and adapt it to your own milestone-based funding system.



To the project's page:
https://yarriva.com/Projects/FlowSol/