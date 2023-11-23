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
    polygon: {
      chainId: 137,
      url: `https://polygon-mainnet.infura.io/v3/421cf5d5904c4d6a98b1067f0819e5f4`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice:80000000000, 
      //gasLimit: 1000000
      //gas: 6000000,
    },     
    hardhat: {
      allowUnlimitedContractSize: false,
      blockGasLimit: 20000000, // 20 million
      forking: {
          url:"https://polygon-mainnet.g.alchemy.com/v2/-g7gWDApXuj5PDlZiwbo1w0-yvV0luSE",
      }
    },    
    buildbear: {
      chainId: 12123,
      url: `https://rpc.buildbear.io/accessible-poggle-the-lesser-a9bdb4e1`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice: 64796492002,
      //gas: 6000000,
    }, 
    buildbear2: {
      chainId: 12018,
      url: `https://rpc.buildbear.io/bloody-dooku-346909c4`,
      accounts: [process.env.PRIVATE_KEYOWNER,process.env.PRIVATE_KEYADMIN],  
      gasPrice: 64796492002,
      //gas: 6000000,
    }  
  },
  etherscan: {
    apiKey: "RNXFFI835YQZSJZFA1C7GTDAJK8KS11RI6",
  },
};

export default config;
