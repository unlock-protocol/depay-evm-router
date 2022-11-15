import deployConfiguration from '../helpers/deploy/configuration'
import deployRouter from '../helpers/deploy/router'
import deployTestToken from '../helpers/deploy/testToken'
import impersonate from '../helpers/impersonate'
import IUniswapV2Router02 from '../../artifacts/contracts/interfaces/IUniswapV2Router02.sol/IUniswapV2Router02.json'
import now from '../helpers/now'
import { CONSTANTS } from 'depay-web3-constants'
import { ethers, unlock } from 'hardhat'
import { expect } from 'chai'
import { findByName } from 'depay-web3-exchanges'
import { Token } from 'depay-web3-tokens'

const blockchain = 'ethereum'
  
// get unlock address in mainnet
const { networks : { 1 : { unlockAddress }} } = unlock
const keyPrice = ethers.utils.parseUnits('0.1', 'ether')
const ZERO = '0x0000000000000000000000000000000000000000'
export const lockParams = {
  expirationDuration: 60 * 60 * 24 * 30, // 30 days
  keyPrice, // in wei
  maxNumberOfKeys: 100,
  name: 'Unlock-Protocol Sample Lock',
}

describe(`DePayRouterV1ApproveAndCallContractAmountsAddressesAddressesAddressesBytes on ${blockchain}`, function() {

  let wallets,
      configuration,
      router,
      contractCallPlugin,
      swapPlugin,
      lock,
      unlockContract,
      keyOwner,
      signer,
      dai

  let exchange = findByName('uniswap_v2')
  let DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F'
  let addressWithDAI = '0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8'
  
  const getSig = (abi, func) => 
    ethers.utils.id(
      Object.keys(abi.functions).find(name => name.includes(func))
    )
    .substring(0, 10)
  
  before(async ()=>{
    wallets = await ethers.getSigners()
    signer = wallets[4]
    keyOwner = wallets[5].address

    // parse contracts from chain
    unlockContract = await unlock.getUnlockContract(unlockAddress)
  })

  it('requires the router', async () => {
    configuration = await deployConfiguration()
    router = await deployRouter(configuration.address)
  })

  it('deploys the contractCallPlugin', async () => {
    const Plugin = await ethers.getContractFactory('DePayRouterV1ApproveAndCallContractAmountsAddressesAddressesAddressesBytes')
    contractCallPlugin = await Plugin.deploy()
    await contractCallPlugin.deployed()
  })

  it('requires a smart contract it can pay into (unlock interface)', async () => {
    const Plugin = await ethers.getContractFactory('TestUnlock')
    unlockContract = await Plugin.deploy()
    await unlockContract.deployed()
  })

  it('approves the plugin', async () => {
    await configuration.connect(wallets[0]).approvePlugin(contractCallPlugin.address)
  })

  it('requires a swap plugin to perform swap payments into smart contracts', async () => {
    const Plugin = await ethers.getContractFactory('DePayRouterV1Uniswap01')
    swapPlugin = await Plugin.deploy(CONSTANTS[blockchain].WRAPPED, exchange.contracts.router.address)
    await swapPlugin.deployed()
  })

  it('approves the plugin', async () => {
    await configuration.connect(wallets[0]).approvePlugin(swapPlugin.address)
  })

  describe('lock price in ETH', () => {
    before(async () => {
      ;({lock} = await unlock.createLock({ 
        unlockAddress, 
        ...lockParams 
      }))
      // make sure we can add multiple keys
      // await lock.setMaxKeysPerAddress(5)
    })
    
    it('lock is set properly', async () => {
      expect(await lock.tokenAddress()).to.equal(ZERO)
      expect(await lock.name()).to.equal(lockParams.name)
      expect(await lock.expirationDuration()).to.equal(lockParams.expirationDuration)
    })

    it('signer has enough ETH to buy a bunch of keys', async () => {
      expect(await ethers.provider.getBalance(signer.address)).to.be.gte(keyPrice.mul(5))
    })

    describe('purchase', () => {
      let calldata, sig, args
  
      beforeEach(async () => {
        sig = getSig(lock.interface, 'purchase')
        args = [
            [keyPrice], // keyPrices
            [keyOwner], // recipients
            [ZERO],
            [ZERO],
            ['0x'], // _data
        ]
        calldata = await lock.interface.encodeFunctionData(sig, args)

        // prepare dai signer
        await impersonate(addressWithDAI)
        signer = await ethers.getSigner(addressWithDAI)
      })
  
      it('calldata is encoded properly', async () => {
        const decoded = lock.interface.decodeFunctionData(sig, calldata)
        expect(lock.interface.decodeFunctionData(sig, calldata)).to.deep.equal(
          decoded.slice(0, args.length)
        )
      })
  
      it.skip('purchase actually works', async () => {
        expect(await lock.balanceOf(keyOwner)).to.equal(0)
        expect(await lock.publicLockVersion()).to.equal(12)
        expect(await lock.unlockProtocol()).to.equal(unlockAddress)
        // const tx = await lock.grantKeys([keyOwner], [6000], [ZERO])
        // const { events } = await tx.wait()
        await lock.purchase(
          [], // keyPrices
          [keyOwner], // recipients
          [ZERO],
          [ZERO],
          [[]], 
        )
      })
      
      it.skip('calldata actually works', async () => {
        await signer.sendTransaction({
          to: lock.address,
          data: calldata,
          value : keyPrice
        })
        expect(await lock.balanceOf(keyOwner)).to.equal(1)
      })
  
      it('swaps DAI to ETH and performs payment into smart contract with ETH', async () => {
        let amountOut = ethers.utils.parseUnits('0.001', 18)
        let exchangeRouter = await ethers.getContractAt(IUniswapV2Router02.abi, exchange.contracts.router.address)
        let amountsIn = await exchangeRouter.getAmountsIn(amountOut, [DAI, CONSTANTS[blockchain].WRAPPED])
        let amountIn = amountsIn[0].toString()
        let DAIToken = await ethers.getContractAt(Token[blockchain].DEFAULT, DAI)
        await DAIToken.connect(signer).approve(router.address, CONSTANTS[blockchain].MAXINT)
        await router.connect(signer).route(
          // path
          [DAI, CONSTANTS[blockchain].NATIVE],
          // amounts
          [amountIn, amountOut, now()+60000, 0, 0, amountOut],
          // addresses
          [lock.address],
          // plugins
          [swapPlugin.address, contractCallPlugin.address],
          // data
          [sig, calldata]
          )
      })
  
      it.skip('swaps ETH to DAI and performs payment into smart contract with DAI', async () => {
        let amountOut = ethers.utils.parseUnits('1', 18)
        let exchangeRouter = await ethers.getContractAt(IUniswapV2Router02.abi, exchange.contracts.router.address)
        let amountsIn = await exchangeRouter.getAmountsIn(amountOut, [CONSTANTS[blockchain].WRAPPED, DAI])
        let amountIn = amountsIn[0].toString()
        await router.connect(signer).route(
          // path
          [CONSTANTS[blockchain].NATIVE, DAI],
          // amounts
          [amountIn, amountOut, now()+60000, 0, 0, amountOut],
          // addresses
          [addressWithDAI, unlockContract.address, addressWithDAI, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
          // plugins
          [swapPlugin.address, contractCallPlugin.address],
          // data
          ['purchase(uint256[],address[],address[],address[],bytes[])', ''],
          // value
          { value: amountsIn[0] }
        )
      })
    })
  })

  describe.skip('lock priced in DAI', () => {
    before(async () => {
      ;({lock} = await unlock.createLock({ 
        unlockAddress, 
        currencyContractAddress: DAI,
        ...lockParams 
      }))
  
      // prepare dai
      await impersonate(addressWithDAI)
      signer = await ethers.getSigner(addressWithDAI)
      dai = await ethers.getContractAt('TestToken', DAI)
      dai.connect(signer).approve(lock.address, keyPrice.mul(100))

      // make sure we can add multiple keys
      // await lock.setMaxKeysPerAddress(5)
    })
    it('lock token is set properly', async () => {
      expect(await lock.tokenAddress()).to.equal(DAI)
    })
  
    it('signer has enough DAI to buy a bunch of keys', async () => {
      expect(await dai.balanceOf(signer.address)).to.be.gte(keyPrice.mul(5))
      expect(await dai.allowance(signer.address, lock.address)).to.be.gte(keyPrice.mul(5))
    })
  })

  // it('resets the token allowance after paying the smart contract to prevent draining the router', async () => {
  //    let amountIn = ethers.utils.parseUnits('1000', 18)
  //   let exchangeRouter = await ethers.getContractAt(IUniswapV2Router02.abi, exchange.contracts.router.address)
  //   let amountsOut = await exchangeRouter.getAmountsOut(amountIn, [CONSTANTS[blockchain].WRAPPED, DAI])
  //   let amountOutMin = amountsOut[amountsOut.length-1].toString()
  //   let DAIToken = await ethers.getContractAt(Token[blockchain].DEFAULT, DAI)
  //   let passedAmount = ethers.BigNumber.from(amountOutMin).mul(2)
  //   await router.connect(wallets[0]).route(
  //     [CONSTANTS[blockchain].NATIVE, DAI], // path
  //     [amountIn, amountOutMin, now()+60000, 0, 0, passedAmount], // amounts
  //     [wallets[0].address, unlockContractAddress.address], // addresses
  //     [swapPlugin.address, contractCallPlugin.address], // plugins
  //     ['doNotMoveTokens(address,uint256,bool)', 'true'], // data
  //     { value: amountIn }
  //   )
  //   let allowance = await DAIToken.allowance(router.address, unlockContractAddress.address)
  //   expect(allowance.toString()).to.eq('0') // it makes sure to only allow what is required to do the payment
  // })
})
