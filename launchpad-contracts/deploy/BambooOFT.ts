import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'BambooOFT'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   'optimism-testnet': {
    //     ...
    //     eid: EndpointId.OPTSEP_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            'BambooOFT', // name
            'BBOFT', // symbol
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
            '1000000000000000000000000', // totalSupply (1 million tokens with 18 decimals)
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)

    // verify contract
    await hre.run('verify:verify', {
        address: address,
        constructorArguments: [
            'BambooOFT',
            'BBOFT',
            endpointV2Deployment.address,
            deployer,
            '1000000000000000000000000',
        ],
    })

    console.log('Verified contract successfully')
}

deploy.tags = [contractName]

export default deploy
