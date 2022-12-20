import {HardhatUserConfig} from "hardhat/types";
import "@shardlabs/starknet-hardhat-plugin"
import "@nomiclabs/hardhat-ethers";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
    starknet: {
        network: "integrated-devnet",
        dockerizedVersion: "0.10.3",
        //venv: "~/cairo_venv"
    },
    networks: {
        integratedDevnet: {
            url: "http://127.0.0.1:5050",
        }
    }
};

export default config;
