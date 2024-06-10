// scripts/deploy_nft1155.js
const { ethers,upgrades } = require("hardhat");
require('dotenv').config();



async function main () {
  // We get the contract to deploy
  const Mid = await ethers.getContractFactory('NFT1155Factory');
  console.log('Deploying Game-NFT1155-Token... :', Mid);
  instance = await upgrades.deployProxy(Mid,["https://nft-air-odin.hiro-token.net/inventory/nft"],{
          kind: "uups",
          redeployImplementation: "always"
        });
  await instance.deployed();
  console.log('Odin NFT1155 Token deployed to:', instance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
