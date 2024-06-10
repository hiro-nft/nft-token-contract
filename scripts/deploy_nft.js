// scripts/deploy.js
const { ethers,upgrades } = require("hardhat");
require('dotenv').config();



async function main () {
  // We get the contract to deploy
  const Mid = await ethers.getContractFactory('NFTCollect');
  console.log('Deploying Game-NFT-Token... :', Mid);
  instance = await upgrades.deployProxy(Mid,["Odin","ODIN","https://nft-odin.hiro-token.net/inventory/nft"],{
          kind: "uups",
          redeployImplementation: "always"
  });
  await instance.deployed();
  console.log('Odin NFT Token deployed to:', instance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
