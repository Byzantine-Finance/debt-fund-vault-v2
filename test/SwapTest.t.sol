// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {VaultV2Mock} from "./mocks/VaultV2Mock.sol";
import {AdapterMock} from "./mocks/AdapterMock.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {ILifiMinimal} from "../src/interfaces/ILifiMinimal.sol";
import {SafeERC20Lib} from "../src/libraries/SafeERC20Lib.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

// Minimal interface for UniswapV2Router02
interface UniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SwapTest is Test {
    VaultV2Mock public vault;
    AdapterMock public adapter;
    ILifiMinimal public lifiDiamond;
    UniswapV2Router02 public uniswap;
    IERC20 public usdc;
    IERC20 public compound;
    IERC20 public usdt;

    // Mainnet fork
    uint256 mainnetBlockNumber = 22181291;
    uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), mainnetBlockNumber);

    // Mainnet contract addresses
    address constant LIFI_DIAMOND = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Mainnet token addresses
    address constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Test variables
    address bot = makeAddr("bot");
    address roleHolder = makeAddr("roleHolder");
    uint256 usdtAmount = 10000 * 10 ** 6;

    function setUp() public {
        // Select the mainnet fork
        vm.selectFork(mainnetFork);

        // Create the ERC20Mock
        ERC20Mock vaultToken = new ERC20Mock(18);

        // Deploy the VaultV2Mock and AdapterMock
        vault = new VaultV2Mock(address(vaultToken), roleHolder, roleHolder, roleHolder, roleHolder);
        adapter = new AdapterMock(address(vault));
        console.log("adapter: ", address(adapter));

        // Initialize contracts
        lifiDiamond = ILifiMinimal(LIFI_DIAMOND);
        uniswap = UniswapV2Router02(UNISWAP_V2_ROUTER);
        usdc = IERC20(USDC);
        usdt = IERC20(USDT);
        compound = IERC20(COMP);

        // Fund bot with USDT
        deal(USDT, bot, usdtAmount);
    }

    function test_claimRewards_swapViaUniswapV2() public {
        // Set the LiFiDiamond address
        adapter.setLifiDiamond(LIFI_DIAMOND);

        // Produce the swap data
        (ILifiMinimal.SwapData[] memory swapData, uint256 minAmountOut) = _produceSwapDataERC20ToERC20();

        // Prepare the ClaimRewardsInputs
        AdapterMock.ClaimRewardsInputs memory inputs = AdapterMock.ClaimRewardsInputs(
            address(usdt), swapData[0].fromAmount, minAmountOut, swapData[0], "integrator", "referrer"
        );

        uint256 usdcBalanceBefore = usdc.balanceOf(address(vault));
        console.log("usdcBalanceBefore", usdcBalanceBefore);

        // Call the claimRewards function to swap the USDT to USDC using UniswapV2
        vm.startPrank(bot);
        SafeERC20Lib.safeApprove(USDT, address(adapter), swapData[0].fromAmount);
        adapter.claimRewards(inputs);
        vm.stopPrank();

        uint256 usdcBalanceAfter = usdc.balanceOf(address(vault));
        assertGt(usdcBalanceAfter, usdcBalanceBefore, "USDC balance should increase");
        console.log("usdcBalanceAfter", usdcBalanceAfter);
    }

    // Use UniswapV2 to swap the USDT to USDC
    function _produceSwapDataERC20ToERC20()
        private
        view
        returns (ILifiMinimal.SwapData[] memory swapData, uint256 minAmountOut)
    {
        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = USDC;

        uint256 amountIn = 150 * 10 ** 6;

        // Calculate minimum input amount
        uint256[] memory amounts = uniswap.getAmountsOut(amountIn, path);
        minAmountOut = amounts[1];
        console.log("amounts[0]", amounts[0]);
        console.log("amounts[1]", amounts[1]);

        // prepare swapData
        swapData = new ILifiMinimal.SwapData[](1);
        swapData[0] = ILifiMinimal.SwapData(
            address(uniswap),
            address(uniswap),
            USDT,
            USDC,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                minAmountOut,
                path,
                LIFI_DIAMOND,
                block.timestamp + 20 minutes
            ),
            true
        );
    }
}
