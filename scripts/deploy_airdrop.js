// scripts/deploy.js
const { ethers,upgrades } = require("hardhat");
require('dotenv').config();



async function main () {
  // We get the contract to deploy
  const Mid = await ethers.getContractFactory('NFT1155Market');
  console.log('Deploying Game-AirDropMarket-Token... :', Mid);
  instance = await upgrades.deployProxy(Mid,["odin-air","0x9171DaDAb6EB49153DF17ac2164Fae1aadA93b27","0x206493b423F54DCDfD9abE6AA86F6CC1Da0029De","0x986473379DDe43bD78b4C64304C01E137BaB7696","0x28053ac8A25d66967B5977e90755fF851646Aea6",300000000],{
	  kind: "uups",
	  redeployImplementation: "always"
  	});
  await instance.deployed();
  console.log('Odin AirDropMarket Token deployed to:', instance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
