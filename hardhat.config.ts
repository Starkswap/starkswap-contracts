import {HardhatUserConfig} from "hardhat/types";
import "@shardlabs/starknet-hardhat-plugin"
import "@nomiclabs/hardhat-ethers";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
    starknet: {
        network: "integrated-devnet",
        // Instead of using the dockerized Scarb, uses the command you provide here
        // Can be a path or a resolvable command
        scarbCommand: "scarb",
        requestTimeout: 90_000 // 90s since default times out on declare
    },
    networks: {
        local: {
            url: "http://127.0.0.1:5050",
        }
    }
};

export default config;
