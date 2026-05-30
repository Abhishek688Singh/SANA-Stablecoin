# Decentralized Stable Coin (stableCoin)

Minimal, Foundry-based implementation of a dollar-pegged, overcollateralized stablecoin.

Short overview
- `DecentralizedStableCoin.sol` — ERC20-like DSC token (mint/burn controlled by `DSCEngine`).
- `DSCEngine.sol` — core protocol: deposit collateral, mint/burn DSC, liquidation logic, price feeds.
- `test/` — unit tests and mocks used by Forge.

Prerequisites
- Install Foundry: https://book.getfoundry.sh/

Quick setup
```bash
git clone <repo>
cd stableCoin
foundryup                 # ensure correct Foundry toolchain
forge build               # compile contracts
forge test                # run tests
```

Key commands
- Build: `forge build`
- Test: `forge test`
- Format: `forge fmt`
- Local node: `anvil`

Remappings and dependencies
- Foundry remappings live in `foundry.toml`. This repo uses libraries in `lib/`, for example:
	- `@openzeppelin/contracts` -> `lib/openzeppelin-contracts/contracts`
	- `@chainlink/contracts` -> `lib/chainlink-brownie-contracts/contracts/`

VS Code settings (project)
- This repo includes `.vscode/settings.json` configured to help the Solidity language server resolve remappings and contract locations. If you change remappings, reload the VS Code window and restart the Solidity language server.

Notes about contracts
- Price feeds: `DSCEngine` maps collateral token addresses -> Chainlink aggregator addresses (`sPriceFeed`). Use `getUsdValue(...)` and `getTokenAmountFromUsd(...)` to convert between token amounts and USD values.
- Storage: `sCollateralDeposited[user][token]` tracks per-user deposits; `sDscMinted[user]` tracks DSC minted by each user.
- Liquidations: implemented in `DSCEngine.liquidate(...)` and rely on Chainlink feed prices; ensure feeds are correctly remapped when compiling locally.

Development tips
- Reload VS Code after editing `foundry.toml` or `.vscode/settings.json`.
- If the Solidity extension doesn't highlight compiler errors, run `forge build` to see definitive compiler output.

Contributing
- Run `forge test` before opening a PR. Keep changes minimal and add tests for new behavior.

License
- MIT

