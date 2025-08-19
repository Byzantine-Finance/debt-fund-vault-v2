// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CompoundV3IntegrationTest.sol";

contract CompoundV3IntegrationInterestTest is CompoundV3IntegrationTest {
    /// forge-config: default.isolate = true
    function testAccrueInterest(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 1, MAX_TEST_ASSETS);
        elapsed = bound(elapsed, 0, 10 * 365 days);

        // setup.
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(compoundAdapter), hex"");
        vault.deposit(assets, address(this));

        uint256 vaultBalanceBefore = comet.balanceOf(address(compoundAdapter));

        skip(elapsed);

        uint256 vaultBalanceAfter = comet.balanceOf(address(compoundAdapter));
        uint256 interestAccrued = vaultBalanceAfter - vaultBalanceBefore;

        assertApproxEqAbs(vault.totalAssets(), assets + interestAccrued, 2 wei, "vault totalAssets");
        assertApproxEqAbs(compoundAdapter.realAssets(), assets + interestAccrued, 2 wei, "Adapter realAssets");
    }

    /// forge-config: default.isolate = true
    function testAccrueInterestAndWithdraw(uint256 assets, uint256 elapsed, uint256 withdrawFactor) public {
        assets = bound(assets, 1, MAX_TEST_ASSETS);
        elapsed = bound(elapsed, 0, 10 * 365 days);
        withdrawFactor = bound(withdrawFactor, 0, 70);

        // setup.
        vm.prank(allocator);
        vault.setLiquidityAdapterAndData(address(compoundAdapter), hex"");
        vault.deposit(assets, address(this));

        uint256 vaultBalanceBefore = comet.balanceOf(address(compoundAdapter));

        skip(elapsed);

        uint256 vaultBalanceAfter = comet.balanceOf(address(compoundAdapter));
        uint256 interestAccrued = vaultBalanceAfter - vaultBalanceBefore;

        uint256 sharesToRedeem = vault.totalSupply() * withdrawFactor / 100;
        vault.redeem(sharesToRedeem, receiver, address(this));

        assertApproxEqAbs(
            vault.totalAssets(),
            (assets * (100 - withdrawFactor) / 100) + (interestAccrued * (100 - withdrawFactor) / 100),
            3 wei,
            "vault totalAssets"
        );
        assertApproxEqAbs(
            usdc.balanceOf(receiver),
            (assets * withdrawFactor / 100) + (interestAccrued * withdrawFactor / 100),
            3 wei,
            "vault balance"
        );
    }
}
