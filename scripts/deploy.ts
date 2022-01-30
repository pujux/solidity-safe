import { ethers, upgrades } from "hardhat";

async function main() {
  const Safe = await ethers.getContractFactory("Safe");
  const proxy = await upgrades.deployProxy(
    Safe,
    [
      [
        "0x390535604b540BdA8765c815A76d8e7be92A3295",
        "0x60CDac3cd0Ba3445D776B31B46E34623723C6482",
      ],
      2,
    ],
    {
      initializer: "initialize",
    }
  );

  await proxy.deployed();

  console.log("Deployed Safe Proxy to " + proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
