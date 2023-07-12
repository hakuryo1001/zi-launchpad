### Deployment to Localhost

To deploy the contracts to localhost for development, read below.
First, start anvil.

```shell
anvil
```

Create a .env file at the root and fill it with the private key given to you by Anvil. It should be like this

```shell
MNEMONIC=test test test test test test test test test test test junk
```

Then run the following script (in another terminal):

```shell
forge script script/AuctionModule.s.sol:AuctionModuleScript --fork-url http://localhost:8545 --broadcast
```

Then, you should get something like this

```shell
Finding wallets for all the necessary addresses...
##
Sending transactions [0 - 0].
⠁ [00:00:00] [################################################################################################################################################################################] 1/1 txes (0.0s)
Transactions saved to: /Users/username/Documents/AuctionModule/broadcast/AuctionModule.s.sol/31337/run-latest.json

##
Waiting for receipts.
⠉ [00:00:00] [############################################################################################################################################################################] 1/1 receipts (0.0s)
##### anvil-hardhat
✅ Hash: 0xebe791ee55c6fba68653e90234991cccdd2c69ffa41ad330701a3fe1e8c214de
Contract Address: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Block: 1
Paid: 0.007642008 ETH (1910502 gas * 4 gwei)

Transactions saved to: /Users/hongjan/Documents/zi-launchpad/broadcast/AuctionModule.s.sol/31337/run-latest.json

Sensitive values saved to: /Users/hongjan/Documents/zi-launchpad/cache/AuctionModule.s.sol/31337/run-latest.json



==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Total Paid: 0.015455508 ETH (3863877 gas * avg 4 gwei)

```

The address `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` is what you would need for using [wagmi](https://wagmi.sh/) to communicate with this local deployment. The contract ABI which is used in the `out` folder, under the name of the contract deployed, in this case `AuctionModule.sol`, will also be necessary for wagmi to run for you to build the frontend.

### Deployment to Sepolia Testnet

In your `.env` file, include the following api keys:

```

SEPOLIA_RPC_URL=YOUR_SEPOLIA_RPC_URL
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
MNEMONIC=YOUR_MNEMONIC

```

Then run

```shell
source .env
```

Then run

```shell
forge script script/AuctionModule.s.sol:AuctionModule --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
```
