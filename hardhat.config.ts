import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      outputSelection: {
        "*": {
          "*": ["*"],
          "": ["*"],
        },
      },
      viaIR: true, // Habilitar viaIR
    },
  },
  networks: {
    hardhat: {
        blockGasLimit: 60000000 // Network block gasLimit
    },    
    buildbear: {
      //chainId: 10792,
      url: `https://rpc.buildbear.io/fuzzy-jek-tono-porkins-c6f23a4b`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice: 20000000000,
      gas: 6000000,
    }    
  },
};

export default config;
