import { ethers, run } from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const contractName = 'BambooPresale'

async function main(hre: HardhatRuntimeEnvironment) {
    const [deployer] = await ethers.getSigners()
    console.log('Deploying contracts with the account:', deployer.address)

    const block = await ethers.provider.getBlock('latest')
    console.log('Current block timestamp:', block.timestamp)
    // Thay các giá trị này bằng giá trị thực tế
    const presaleTokenAddress = '0xAfB4305a792Bb9e90816A26E4ecCcD53D8D0298D' // Địa chỉ token ERC20
    const paymentToken = '0xAfB4305a792Bb9e90816A26E4ecCcD53D8D0298D' // USDT hoặc 0x0000000000000000000000000000000000000000 nếu dùng native token
    const targetAmount = ethers.utils.parseUnits('1000', 18) // Ví dụ: 1000 token
    const softCap = ethers.utils.parseUnits('500', 18) // Ví dụ: 500 token
    const startTime = block.timestamp + 7200 // Bắt đầu sau 2 giờ từ block timestamp
    const endTime = startTime + 7 * 24 * 3600 // Kết thúc sau 7 ngày từ startTime
    // const startTime = 1751706045
    // const endTime = 1751751741
    const totalTokens = ethers.utils.parseUnits('10000', 18) // Tổng token phân bổ
    const minContribution = ethers.utils.parseUnits('1', 18) // Tối thiểu 1 token
    const maxContribution = ethers.utils.parseUnits('100', 18) // Tối đa 100 token
    const userWallet = '0xAfB4305a792Bb9e90816A26E4ecCcD53D8D0298D' // Ví nhận tiền
    const systemWallet = '0xAfB4305a792Bb9e90816A26E4ecCcD53D8D0298D' // Ví nhận phí
    const initialOwner = deployer.address // Chủ sở hữu hợp đồng

    const BambooPresale = await ethers.getContractFactory(contractName)
    const bambooPreSale = await BambooPresale.deploy(
        presaleTokenAddress,
        paymentToken,
        targetAmount,
        softCap,
        startTime,
        endTime,
        totalTokens,
        minContribution,
        maxContribution,
        userWallet,
        systemWallet,
        initialOwner
    )

    await bambooPreSale.deployed()
    console.log('BambooPresale deployed to:', bambooPreSale.address)

    await run(`verify:verify --network ${hre.network.name}`, {
        address: bambooPreSale.address,
        constructorArguments: [
            presaleTokenAddress,
            paymentToken,
            targetAmount,
            softCap,
            startTime,
            endTime,
            totalTokens,
            minContribution,
            maxContribution,
            userWallet,
            systemWallet,
            initialOwner,
        ],
    })
    console.log('Verification successful!')
}

// main()
//     .then(() => process.exit(0))
//     .catch((error) => {
//         console.error(error)
//         process.exit(1)
//     })
