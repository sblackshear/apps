// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module mkt::collection_bidding_tests {
    use sui::coin;
    use sui::test_utils;
    use sui::tx_context::TxContext;
    use sui::kiosk_test_utils::{Self as test, Asset};
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap
    };

    use mkt::collection_bidding::{Self as bidding};

    /// The Marketplace witness.
    public struct MyMarket has drop {}

    #[test]
    fun test_simple_bid() {
        let ctx = &mut test::ctx();
        let (mut buyer_kiosk, buyer_cap) = test::get_kiosk(ctx);

        mkt::extension::add(&mut buyer_kiosk, &buyer_cap, ctx);

        // place bids on an Asset: 100 MIST
        bidding::place_bids<Asset, MyMarket>(
            &mut buyer_kiosk,
            &buyer_cap,
            vector[
                test::get_sui(100, ctx),
                test::get_sui(300, ctx)
            ],
            ctx
        );

        // prepare the seller Kiosk
        let (mut seller_kiosk, seller_cap) = test::get_kiosk(ctx);
        let (asset, asset_id) = test::get_asset(ctx);

        // place the asset and create a MarketPurchaseCap
        // bidding::add(&mut seller_kiosk, &seller_cap, ctx);
        seller_kiosk.place(&seller_cap, asset);

        let (asset_policy, asset_policy_cap) = get_policy<Asset>(ctx);
        let (mkt_policy, mkt_policy_cap) = get_policy<MyMarket>(ctx);

        // take the bid and perform the purchase
        let (asset_request, mkt_request) = bidding::accept_market_bid(
            &mut buyer_kiosk,
            &mut seller_kiosk,
            &seller_cap,
            &asset_policy,
            asset_id,
            300,
            false,
            ctx
        );

        asset_policy.confirm_request(asset_request);
        mkt_policy.confirm_request(mkt_request);

        assert!(buyer_kiosk.has_item(asset_id), 0);
        assert!(!seller_kiosk.has_item(asset_id), 1);
        assert!(seller_kiosk.profits_amount() == 300, 2);

        // do it all over again
        let (asset, asset_id) = test::get_asset(ctx);
        seller_kiosk.place(&seller_cap, asset);

        // second bid
        let (asset_request, mkt_request) = bidding::accept_market_bid(
            &mut buyer_kiosk,
            &mut seller_kiosk,
            &seller_cap,
            &asset_policy,
            asset_id,
            400,
            false,
            ctx
        );

        asset_policy.confirm_request(asset_request);
        mkt_policy.confirm_request(mkt_request);

        assert!(buyer_kiosk.has_item(asset_id), 3);
        assert!(!seller_kiosk.has_item(asset_id), 4);
        assert!(seller_kiosk.profits_amount() == 400, 5);

        test_utils::destroy(seller_kiosk);
        test_utils::destroy(buyer_kiosk);
        test_utils::destroy(seller_cap);
        test_utils::destroy(buyer_cap);

        return_policy(asset_policy, asset_policy_cap, ctx);
        return_policy(mkt_policy, mkt_policy_cap, ctx);
    }

    fun get_policy<T>(ctx: &mut TxContext): (TransferPolicy<T>, TransferPolicyCap<T>) {
        policy::new_for_testing(ctx)
    }

    fun return_policy<T>(
        policy: TransferPolicy<T>, policy_cap: TransferPolicyCap<T>, ctx: &mut TxContext
    ): u64 {
        coin::burn_for_testing(
            policy::destroy_and_withdraw(policy, policy_cap, ctx)
        )
    }
}
