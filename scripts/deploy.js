require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const { SUBSCRIPTION_ID } = process.env;

  const cryptoLotto = await hre.ethers.deployContract("CryptoLotto", [
    SUBSCRIPTION_ID,
  ]);

  await cryptoLotto.waitForDeployment();

  console.log(`CryptoLotto deployed to ${cryptoLotto.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
