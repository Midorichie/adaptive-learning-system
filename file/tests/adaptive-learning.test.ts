import { describe, it, beforeEach } from 'vitest';
import { Chain, Account, Tx, types } from '@hirosystems/clarinet-sdk';

describe('Adaptive Learning Contract Tests', () => {
    let chain: Chain;
    let accounts: Map<string, Account>;
    let deployer: Account;
    let wallet1: Account;

    beforeEach(() => {
        // Setup will be injected by the Clarinet environment
        chain = Chain.fromGlobalThis();
        accounts = chain.accounts;
        deployer = accounts.get('deployer')!;
        wallet1 = accounts.get('wallet_1')!;
    });

    it("Ensures proper initialization of student profile", async () => {
        let block = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "initialize-student",
                [],
                wallet1.address
            )
        ]);

        // Assert successful initialization
        block.receipts[0].result.expectOk();
        
        // Verify profile data
        let profile = chain.callReadOnlyFn(
            "adaptive-learning",
            "get-student-profile",
            [types.principal(wallet1.address)],
            deployer.address
        );
        
        profile.result.expectSome();
    });

    it("Prevents duplicate student initialization", async () => {
        // First initialization
        let block = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "initialize-student",
                [],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk();

        // Second initialization attempt
        let block2 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "initialize-student",
                [],
                wallet1.address
            )
        ]);
        block2.receipts[0].result.expectErr(types.uint(103)); // err-student-exists
    });

    it("Validates assessment submission and cooldown period", async () => {
        // Initialize student
        let block = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "initialize-student",
                [],
                wallet1.address
            )
        ]);

        // Submit first assessment
        let block2 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "submit-assessment",
                [types.uint(1), types.uint(85)],
                wallet1.address
            )
        ]);
        block2.receipts[0].result.expectErr(types.uint(105)); // err-invalid-subject

        // Add subject first
        let block3 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "add-subject",
                [types.uint(1), types.ascii("Mathematics"), types.uint(10)],
                deployer.address
            )
        ]);
        block3.receipts[0].result.expectOk();

        // Now submit assessment
        let block4 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "submit-assessment",
                [types.uint(1), types.uint(85)],
                wallet1.address
            )
        ]);
        block4.receipts[0].result.expectOk();

        // Try immediate resubmission (should fail due to cooldown)
        let block5 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "submit-assessment",
                [types.uint(1), types.uint(90)],
                wallet1.address
            )
        ]);
        block5.receipts[0].result.expectErr(types.uint(106)); // err-cooldown-period
    });

    it("Tests administrative functions and pausing", async () => {
        // Pause contract
        let block = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "set-paused",
                [types.bool(true)],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk();

        // Try to initialize student while paused
        let block2 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "initialize-student",
                [],
                wallet1.address
            )
        ]);
        block2.receipts[0].result.expectErr(types.uint(107)); // contract paused error

        // Non-owner cannot unpause
        let block3 = chain.mineBlock([
            Tx.contractCall(
                "adaptive-learning",
                "set-paused",
                [types.bool(false)],
                wallet1.address
            )
        ]);
        block3.receipts[0].result.expectErr(types.uint(100)); // err-owner-only
    });
});
