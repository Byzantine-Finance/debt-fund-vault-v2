// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC4626AdapterIntegrationTest.sol";

contract ERC4626AdapterIntegrationSkyTest is ERC4626AdapterIntegrationTest {
    uint256 constant MAX_TEST_ASSETS_SKY = 1e12;

    // Addresses of Sky sUSDC, sUSDS, and USDS on Ethereum Mainnet
    IERC4626 internal sUSDC = IERC4626(0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE);
    IERC4626 internal sUSDS = IERC4626(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    IERC20 internal usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);

    // Sky Adapter data
    IERC4626Adapter internal skyAdapter;
    bytes32 internal expectedSkyAdapterId;
    bytes internal expectedSkyAdapterIdData;

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(sUSDC), "sUSDC");
        vm.label(address(sUSDS), "sUSDS");
        vm.label(address(usds), "usds");

        skyAdapter = IERC4626Adapter(erc4626AdapterFactory.createERC4626Adapter(address(vault), address(sUSDC)));
        expectedSkyAdapterIdData = abi.encode("this", address(skyAdapter));
        expectedSkyAdapterId = keccak256(expectedSkyAdapterIdData);
        vm.label(address(skyAdapter), "skyAdapter");

        _setIsAdapter(address(skyAdapter), true);
        _setAdapterAbsoluteCap(expectedSkyAdapterIdData, type(uint128).max);
        _setAdapterRelativeCap(expectedSkyAdapterIdData, WAD);

        // Set Sky as liquidity adapter
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(skyAdapter), "");
    }

    function testsUSDCDeposit(uint256 assets) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS_SKY);

        uint256 USDSBalanceBefore = usds.balanceOf(address(sUSDC));
        uint256 expectedReceivedShares = sUSDC.previewDeposit(assets);
        // USDC are swapped to USDS that are deposited to sUSDS
        vault.deposit(assets, address(this));

        assertEq(sUSDC.balanceOf(address(skyAdapter)), expectedReceivedShares, "adapter sUSDC balance");
        assertApproxEqAbs(
            sUSDC.convertToAssets(sUSDC.balanceOf(address(skyAdapter))), assets, 1 wei, "adapter sUSDC conversion"
        );

        uint256 USDSBalanceAfter = usds.balanceOf(address(sUSDC));
        assertGe(USDSBalanceBefore + assets, USDSBalanceAfter, "sUSDS USDS balance");
    }

    /// forge-config: default.isolate = true
    function testsUSDCWithdrawInterest(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 0, MAX_TEST_ASSETS_SKY);
        elapsed = bound(elapsed, 1, 10 * 365 days);

        vault.deposit(assets, address(this));

        skip(elapsed);

        uint256 newAssets = sUSDC.convertToAssets(sUSDC.balanceOf(address(skyAdapter)));
        uint256 interest = newAssets - assets;

        vault.redeem(vault.balanceOf(address(this)), receiver, address(this));
        assertApproxEqAbs(usdc.balanceOf(receiver), assets + interest, 1 wei, "withdraw all");
    }
}
