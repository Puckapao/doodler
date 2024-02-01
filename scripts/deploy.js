// scripts/deploy.js

async function main() {
  // We get the contract to deploy
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const AdventurerNFT = await ethers.getContractFactory("AdventurerNFT");
  const adventurerNFT = await AdventurerNFT.deploy("BaseTokenURI", ethers.parseEther("0.05"));

  await adventurerNFT.waitForDeployment();

  console.log("AdventurerNFT deployed to:", await adventurerNFT.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
