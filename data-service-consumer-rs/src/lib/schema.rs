table! {
    use diesel::sql_types::*;

    asset_origins (asset_id) {
        asset_id -> Varchar,
        first_asset_update_uid -> Int8,
        origin_transaction_id -> Varchar,
        issuer -> Varchar,
        issue_height -> Int4,
        issue_time_stamp -> Timestamptz,
    }
}

table! {
    use diesel::sql_types::*;

    asset_updates (superseded_by, asset_id) {
        block_uid -> Int8,
        uid -> Int8,
        superseded_by -> Int8,
        asset_id -> Varchar,
        decimals -> Int2,
        name -> Varchar,
        description -> Varchar,
        reissuable -> Bool,
        volume -> Int8,
        script -> Nullable<Varchar>,
        sponsorship -> Nullable<Int8>,
        nft -> Bool,
    }
}

table! {
    asset_updates_uid_seq (last_value) {
        last_value -> BigInt,
    }
}

table! {
    use diesel::sql_types::*;

    assets_metadata (asset_id) {
        asset_id -> Varchar,
        asset_name -> Nullable<Varchar>,
        ticker -> Nullable<Varchar>,
        height -> Nullable<Int4>,
    }
}

table! {
    use diesel::sql_types::*;
    use diesel_full_text_search::TsVector;

    assets_names_map (asset_id) {
        asset_id -> Varchar,
        asset_name -> Varchar,
        searchable_asset_name -> TsVector,
    }
}

table! {
    use diesel::sql_types::*;

    blocks (height) {
        schema_version -> Int2,
        time_stamp -> Timestamp,
        reference -> Varchar,
        nxt_consensus_base_target -> Int8,
        nxt_consensus_generation_signature -> Varchar,
        generator -> Varchar,
        signature -> Varchar,
        fee -> Int8,
        blocksize -> Nullable<Int4>,
        height -> Int4,
        features -> Nullable<Array<Int2>>,
    }
}

table! {
    use diesel::sql_types::*;

    blocks_microblocks (id) {
        uid -> Int8,
        id -> Varchar,
        height -> Int4,
        time_stamp -> Nullable<Timestamptz>,
    }
}

table! {
    use diesel::sql_types::*;

    candles (interval, time_start, amount_asset_id, price_asset_id, matcher) {
        time_start -> Timestamp,
        amount_asset_id -> Varchar,
        price_asset_id -> Varchar,
        low -> Numeric,
        high -> Numeric,
        volume -> Numeric,
        quote_volume -> Numeric,
        max_height -> Int4,
        txs_count -> Int4,
        weighted_average_price -> Numeric,
        open -> Numeric,
        close -> Numeric,
        interval -> Varchar,
        matcher -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    pairs (first_price, last_price, amount_asset_id, price_asset_id, matcher) {
        amount_asset_id -> Varchar,
        price_asset_id -> Varchar,
        first_price -> Numeric,
        last_price -> Numeric,
        volume -> Numeric,
        volume_waves -> Nullable<Numeric>,
        quote_volume -> Numeric,
        high -> Numeric,
        low -> Numeric,
        weighted_average_price -> Numeric,
        txs_count -> Int4,
        matcher -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    tickers (asset_id) {
        asset_id -> Text,
        ticker -> Text,
    }
}

table! {
    use diesel::sql_types::*;

    txs (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Nullable<Varchar>,
        sender_public_key -> Nullable<Varchar>,
        status -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_1 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Nullable<Varchar>,
        sender_public_key -> Nullable<Varchar>,
        status -> Varchar,
        recipient -> Varchar,
        amount -> Int8,
    }
}

table! {
    use diesel::sql_types::*;

    txs_10 (id, time_stamp) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        alias -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_11 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        attachment -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_11_transfers (tx_id, position_in_tx) {
        tx_id -> Varchar,
        recipient -> Varchar,
        amount -> Int8,
        position_in_tx -> Int2,
    }
}

table! {
    use diesel::sql_types::*;

    txs_12 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_12_data (tx_id, position_in_tx) {
        tx_id -> Text,
        data_key -> Text,
        data_type -> Nullable<Text>,
        data_value_integer -> Nullable<Int8>,
        data_value_boolean -> Nullable<Bool>,
        data_value_binary -> Nullable<Text>,
        data_value_string -> Nullable<Text>,
        position_in_tx -> Int2,
    }
}

table! {
    use diesel::sql_types::*;

    txs_13 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        script -> Nullable<Varchar>,
    }
}

table! {
    use diesel::sql_types::*;

    txs_14 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        min_sponsored_asset_fee -> Nullable<Int8>,
    }
}

table! {
    use diesel::sql_types::*;

    txs_15 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        script -> Nullable<Varchar>,
    }
}

table! {
    use diesel::sql_types::*;

    txs_16 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        dapp -> Varchar,
        function_name -> Nullable<Varchar>,
        fee_asset_id -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_16_args (tx_id, position_in_args) {
        tx_id -> Text,
        arg_type -> Text,
        arg_value_integer -> Nullable<Int8>,
        arg_value_boolean -> Nullable<Bool>,
        arg_value_binary -> Nullable<Text>,
        arg_value_string -> Nullable<Text>,
        arg_value_list -> Nullable<Jsonb>,
        position_in_args -> Int2,
    }
}

table! {
    use diesel::sql_types::*;

    txs_16_payment (tx_id, position_in_payment) {
        tx_id -> Text,
        amount -> Int8,
        asset_id -> Nullable<Text>,
        position_in_payment -> Int2,
    }
}

table! {
    use diesel::sql_types::*;

    txs_17 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        asset_name -> Varchar,
        description -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_2 (id, time_stamp) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        recipient -> Varchar,
        amount -> Int8,
    }
}

table! {
    use diesel::sql_types::*;

    txs_3 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        asset_name -> Varchar,
        description -> Varchar,
        quantity -> Int8,
        decimals -> Int2,
        reissuable -> Bool,
        script -> Nullable<Varchar>,
    }
}

table! {
    use diesel::sql_types::*;

    txs_4 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        amount -> Int8,
        recipient -> Varchar,
        fee_asset -> Varchar,
        attachment -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    txs_5 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        quantity -> Int8,
        reissuable -> Bool,
    }
}

table! {
    use diesel::sql_types::*;

    txs_6 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        asset_id -> Varchar,
        amount -> Int8,
    }
}

table! {
    use diesel::sql_types::*;

    txs_7 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        order1 -> Jsonb,
        order2 -> Jsonb,
        amount_asset -> Varchar,
        price_asset -> Varchar,
        amount -> Int8,
        price -> Int8,
        buy_matcher_fee -> Int8,
        sell_matcher_fee -> Int8,
    }
}

table! {
    use diesel::sql_types::*;

    txs_8 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        recipient -> Varchar,
        amount -> Int8,
    }
}

table! {
    use diesel::sql_types::*;

    txs_9 (id) {
        height -> Int4,
        tx_type -> Int2,
        id -> Varchar,
        time_stamp -> Timestamp,
        signature -> Nullable<Varchar>,
        fee -> Int8,
        proofs -> Nullable<Array<Text>>,
        tx_version -> Nullable<Int2>,
        sender -> Varchar,
        sender_public_key -> Varchar,
        status -> Varchar,
        lease_id -> Varchar,
    }
}

table! {
    use diesel::sql_types::*;

    waves_data (height) {
        height -> Int4,
        quantity -> Numeric,
    }
}

joinable!(txs_1 -> blocks (height));
joinable!(txs_10 -> blocks (height));
joinable!(txs_11 -> blocks (height));
joinable!(txs_11_transfers -> txs_11 (tx_id));
joinable!(txs_12 -> blocks (height));
joinable!(txs_12_data -> txs_12 (tx_id));
joinable!(txs_13 -> blocks (height));
joinable!(txs_14 -> blocks (height));
joinable!(txs_15 -> blocks (height));
joinable!(txs_16 -> blocks (height));
joinable!(txs_16_args -> txs_16 (tx_id));
joinable!(txs_16_payment -> txs_16 (tx_id));
joinable!(txs_17 -> blocks (height));
joinable!(txs_2 -> blocks (height));
joinable!(txs_3 -> blocks (height));
joinable!(txs_4 -> blocks (height));
joinable!(txs_5 -> blocks (height));
joinable!(txs_6 -> blocks (height));
joinable!(txs_7 -> blocks (height));
joinable!(txs_8 -> blocks (height));
joinable!(txs_9 -> blocks (height));
joinable!(waves_data -> blocks (height));

allow_tables_to_appear_in_same_query!(
    asset_origins,
    asset_updates,
    assets_metadata,
    assets_names_map,
    blocks,
    blocks_microblocks,
    candles,
    pairs,
    tickers,
    txs,
    txs_1,
    txs_10,
    txs_11,
    txs_11_transfers,
    txs_12,
    txs_12_data,
    txs_13,
    txs_14,
    txs_15,
    txs_16,
    txs_16_args,
    txs_16_payment,
    txs_17,
    txs_2,
    txs_3,
    txs_4,
    txs_5,
    txs_6,
    txs_7,
    txs_8,
    txs_9,
    waves_data,
);
