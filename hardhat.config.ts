import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
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
    buildbear: {
      url: `https://rpc.buildbear.io/fuzzy-jek-tono-porkins-c6f23a4b`,
      accounts: [process.env.PRIVATE_KEY],  
      gasPrice: 20000000000,  
    }    
  }
};

export default config;
