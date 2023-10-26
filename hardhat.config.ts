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
      allowUnlimitedContractSize: false,
      blockGasLimit: 20000000, // 20 million
      forking: {
          url:"https://polygon-mainnet.g.alchemy.com/v2/-g7gWDApXuj5PDlZiwbo1w0-yvV0luSE",
      }
    },    
    buildbear: {
      chainId: 10792,
      url: `https://rpc.buildbear.io/fuzzy-jek-tono-porkins-c6f23a4b`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice: 30000000000,
      //gas: 6000000,
    }, 
    buildbear2: {
      chainId: 12018,
      url: `https://rpc.buildbear.io/bloody-dooku-346909c4`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice: 30000000000,
      //gas: 6000000,
    }  
  }
};

export default config;
