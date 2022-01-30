import { ethers, upgrades } from "hardhat";

const PROXY: string = process.env.PROXY_CONTRACT ?? "";

async function main() {
  const Safe = await ethers.getContractFactory("Safe");
  await upgrades.upgradeProxy(PROXY, Safe);
  console.log("Upgraded proxy implementation");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
