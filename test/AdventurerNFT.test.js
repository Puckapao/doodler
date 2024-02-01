const { expect } = require("chai");
const { ethers } = require("hardhat");

const AdventurerClass = {
    Adventurer: 0,
    Squire: 1,
	Magician: 2,
	Thief: 3,
	Cleric: 4
};

describe("AdventurerNFT", function () {
	let adventurerNFT;
	let owner;
	let addr1

	beforeEach(async function () {
		[owner, addr1] = await ethers.getSigners();

		const AdventurerNFT = await ethers.getContractFactory("AdventurerNFT");
		adventurerNFT = await AdventurerNFT.deploy("baseURI/", ethers.parseEther("1")); // 1 ether in wei
	});

	it("Should set the right owner", async function () {
		expect(await adventurerNFT.owner()).to.equal(owner.address);
	});

	it("Should mint a new token", async function () {
		const mintTx = await adventurerNFT.connect(owner).mint("Hero", [1, 2, 3, 4, 5, 5], { value: ethers.parseEther("1") });
		await mintTx.wait();

		const ownerOfToken = await adventurerNFT.ownerOf(1);
		expect(ownerOfToken).to.equal(owner.address);
	});

	it("Should revert minting with insufficient funds", async function () {
		await expect(
				adventurerNFT.connect(owner).mint("Hero", [1, 2, 3, 4, 5, 5], { value: ethers.parseEther("0.5") })
		).to.be.revertedWith("Insufficient funds");
	});

	it("Should correctly set the token URI for a minted token", async function () {
		const mintTx = await adventurerNFT.connect(owner).mint("Hero", [1, 2, 3, 4, 5, 5], { value: ethers.parseEther("1") });
		await mintTx.wait();

		const tokenURI = await adventurerNFT.tokenURI(1);
		expect(tokenURI).to.equal("baseURI/1");
	});
	
	it("Should revert minting if total status points exceed the limit", async function () {
		await expect(
				adventurerNFT.connect(owner).mint("Hero", [10, 10, 10, 10, 10, 10], { value: ethers.parseEther("1") })
		).to.be.revertedWith("Total status points exceed the limit");
	});
	
	it("Should transfer ownership of a token", async function () {
		const mintTx = await adventurerNFT.connect(owner).mint("Hero", [1, 2, 3, 4, 5, 5], { value: ethers.parseEther("1") });
		await mintTx.wait();

		const transferTx = await adventurerNFT.connect(owner).transferFrom(owner.address, addr1.address, 1);
		await transferTx.wait();

		expect(await adventurerNFT.ownerOf(1)).to.equal(addr1.address);
	});

	it("Should set class multiplier", async function () {
		// Mint a new adventurer and get its ID
		await adventurerNFT.connect(owner).mint("Hero", [20, 0, 0, 0, 0, 0], { value: ethers.parseEther("1") });
		const tokenId = 1; // Assuming the first token ID is 1
	
		// Define the class multipliers you want to set
		const newMultipliers = {
			str: 15,
			agi: 12,
			vit: 12,
			dex: 11,
			intel: 10,
			luk: 10,
		};
	
		// Set class multiplier for the adventurer
		await adventurerNFT.connect(owner).setClassMultiplier(tokenId, newMultipliers);
	
		// Retrieve the adventurer's class multipliers
		const classMultipliers = await adventurerNFT.classMultipliers(tokenId);
	
		// Check if the class multipliers are set correctly
		expect(classMultipliers.str).to.equal(newMultipliers.str);
		expect(classMultipliers.agi).to.equal(newMultipliers.agi);
		expect(classMultipliers.vit).to.equal(newMultipliers.vit);
		expect(classMultipliers.dex).to.equal(newMultipliers.dex);
		expect(classMultipliers.intel).to.equal(newMultipliers.intel);
		expect(classMultipliers.luk).to.equal(newMultipliers.luk);
	});
	
	it("Should have the same EXP from viewExp and claimExp as in adventurerInfo", async function () {
		await adventurerNFT.connect(owner).mint("Hero", [20, 0, 0, 0, 0, 0], { value: ethers.parseEther("1") });
		await adventurerNFT.connect(owner).adventure(1);
	
		// Simulate the passing of 100 blocks
		for (let i = 0; i < 100; i++) {
			await network.provider.send("evm_mine");
		}

		// View EXP before claiming
		const expFromViewExp = await adventurerNFT.connect(owner).viewExp(1);
		console.log("EXP from viewExp:", expFromViewExp.toString());

		// Claim EXP
		const tx = await adventurerNFT.connect(owner).claimExp(1);
		await tx.wait();

		// Retrieve the emitted event from ClaimExp
		const events = await adventurerNFT.queryFilter(adventurerNFT.filters.ExpClaimed());
    
		// Ensure there is at least one emitted event
		expect(events.length).to.be.at.least(1);
	
		// Check if the emitted event contains the correct accruedExp value
		const expFromClaimExp = events[0].args.accruedExp;
		console.log("Accrued EXP from ClaimExp:", expFromClaimExp.toString());

		// Retrieve adventurer info to check EXP
		const adventurer = await adventurerNFT.getAdventurerInfo(1);
		console.log("Accrued EXP from adventurerInfo:", adventurer.accruedExp.toString());
		
	
		// Check if EXP from viewExp and adventurerInfo match
		expect(expFromViewExp).to.lessThan(adventurer.accruedExp);
		expect(expFromViewExp).to.lessThan(expFromClaimExp);
		expect(expFromClaimExp).to.equal(adventurer.accruedExp);

		// Ensure the adventure ended and EXP was claimed
		expect(adventurer.onAdventure).to.equal(false);
		expect(adventurer.accruedExp).to.be.above(0);
	});

	it("Should successfully claim exp and level up then upgrade status points", async function () {
		await adventurerNFT.connect(owner).mint("Hero", [20, 0, 0, 0, 0, 0], { value: ethers.parseEther("1") });
		await adventurerNFT.connect(owner).adventure(1);
	
		// Simulate the passing of 100 blocks
		for (let i = 0; i < 100; i++) {
			await network.provider.send("evm_mine");
		}
		// Claim EXP
		const tx = await adventurerNFT.connect(owner).claimExp(1);
		await tx.wait();

		// Retrieve the emitted event from ClaimExp
		const events = await adventurerNFT.queryFilter(adventurerNFT.filters.ExpClaimed());
    
		// Ensure there is at least one emitted event
		expect(events.length).to.be.at.least(1);
	
		// Check if the emitted event contains the correct accruedExp value
		const expFromClaimExp = events[0].args.accruedExp;
		console.log("Accrued EXP from ClaimExp:", expFromClaimExp.toString());

		await adventurerNFT.connect(owner).levelUp(1);

		await adventurerNFT.connect(owner).upgradeStatuses(1, 6, 0, 0, 0, 0, 0);

		// Retrieve adventurer info to check EXP
		const adventurer = await adventurerNFT.getAdventurerInfo(1);
		
		// Check if exp has been used
		expect(expFromClaimExp).to.greaterThan(adventurer.accruedExp);
		// Check if status points has been used
		expect(adventurer.statusPoints).to.equal(0);
		// Check if STR is equal 26
		expect(adventurer.stats[0]).to.equal(26);

		// Ensure the adventure ended
		expect(adventurer.onAdventure).to.equal(false);
	});

	it("Should level up to level 10 and change class", async function () {
		await adventurerNFT.connect(owner).mint("Hero", [20, 0, 0, 0, 0, 0], { value: ethers.parseEther("1") });
		await adventurerNFT.connect(owner).adventure(1);

		// Simulate the passing of 100 blocks
		for (let i = 0; i < 1000; i++) {
			await network.provider.send("evm_mine");
		}
		// Claim EXP
		await adventurerNFT.connect(owner).claimExp(1);

		for (let i = 0; i < 9; i++) {
			await adventurerNFT.connect(owner).levelUp(1);

			let adv = await adventurerNFT.getAdventurerInfo(1);
			console.log("Current Level: ", adv.level.toString());
			console.log("Current Exp Left: ", adv.accruedExp.toString());
			console.log("Current Status Points: ", adv.statusPoints.toString());

			await new Promise((resolve) => setTimeout(resolve, 3 * 1000));
		}

		await adventurerNFT.connect(owner).changeClass(1, 1);

		// Retrieve adventurer info to check EXP
		const adventurer = await adventurerNFT.getAdventurerInfo(1);
		
		// Check if status points has been used
		expect(adventurer.statusPoints).to.equal(162);
		// Check if level is 10
		expect(adventurer.level).to.equal(10);
		// Check if class has been changed to Squire
		expect(adventurer.currentClass).to.equal(AdventurerClass.Squire);

		// Ensure the adventure ended
		expect(adventurer.onAdventure).to.equal(false);
	});
	
});
