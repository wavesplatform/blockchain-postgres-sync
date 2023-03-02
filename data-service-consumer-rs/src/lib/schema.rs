// @generated automatically by Diesel CLI.

diesel::table! {
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

diesel::table! {
    use diesel::sql_types::*;

    asset_tickers (superseded_by, asset_id) {
        uid -> Int8,
        superseded_by -> Int8,
        block_uid -> Int8,
        asset_id -> Text,
        ticker -> Text,
    }
}

diesel::table! {
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
    asset_tickers_uid_seq (last_value) {
        last_value -> BigInt,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    assets_metadata (asset_id) {
        asset_id -> Varchar,
        asset_name -> Nullable<Varchar>,
        ticker -> Nullable<Varchar>,
        height -> Nullable<Int4>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    blocks_microblocks (id) {
        uid -> Int8,
        id -> Varchar,
        height -> Int4,
        time_stamp -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    candles (interval, time_start, amount_asset_id, price_asset_id, matcher_address) {
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
        matcher_address -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    pairs (amount_asset_id, price_asset_id, matcher_address) {
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
        matcher_address -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs (uid, id, time_stamp) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Nullable<Varchar>,
        sender_public_key -> Nullable<Varchar>,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_1 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Nullable<Varchar>,
        sender_public_key -> Nullable<Varchar>,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        recipient_address -> Varchar,
        recipient_alias -> Nullable<Varchar>,
        amount -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_10 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        alias -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_11 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        attachment -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_11_transfers (tx_uid, position_in_tx) {
        tx_uid -> Int8,
        recipient_address -> Varchar,
        recipient_alias -> Nullable<Varchar>,
        amount -> Int8,
        position_in_tx -> Int2,
        height -> Int4,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_12 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_12_data (tx_uid, position_in_tx) {
        tx_uid -> Int8,
        data_key -> Text,
        data_type -> Nullable<Text>,
        data_value_integer -> Nullable<Int8>,
        data_value_boolean -> Nullable<Bool>,
        data_value_binary -> Nullable<Text>,
        data_value_string -> Nullable<Text>,
        position_in_tx -> Int2,
        height -> Int4,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_13 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        script -> Nullable<Varchar>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_14 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        min_sponsored_asset_fee -> Nullable<Int8>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_15 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        script -> Nullable<Varchar>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_16 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        dapp_address -> Varchar,
        dapp_alias -> Nullable<Varchar>,
        function_name -> Nullable<Varchar>,
        fee_asset_id -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_16_args (tx_uid, position_in_args) {
        arg_type -> Text,
        arg_value_integer -> Nullable<Int8>,
        arg_value_boolean -> Nullable<Bool>,
        arg_value_binary -> Nullable<Text>,
        arg_value_string -> Nullable<Text>,
        arg_value_list -> Nullable<Jsonb>,
        position_in_args -> Int2,
        tx_uid -> Int8,
        height -> Nullable<Int4>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_16_payment (tx_uid, position_in_payment) {
        tx_uid -> Int8,
        amount -> Int8,
        position_in_payment -> Int2,
        height -> Nullable<Int4>,
        asset_id -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_17 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        asset_name -> Varchar,
        description -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_18 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Nullable<Varchar>,
        sender_public_key -> Nullable<Varchar>,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        payload -> Bytea,
        function_name -> Nullable<Varchar>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_18_args (tx_uid, position_in_args) {
        arg_type -> Text,
        arg_value_integer -> Nullable<Int8>,
        arg_value_boolean -> Nullable<Bool>,
        arg_value_binary -> Nullable<Text>,
        arg_value_string -> Nullable<Text>,
        arg_value_list -> Nullable<Jsonb>,
        position_in_args -> Int2,
        tx_uid -> Int8,
        height -> Nullable<Int4>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_18_payment (tx_uid, position_in_payment) {
        tx_uid -> Int8,
        amount -> Int8,
        position_in_payment -> Int2,
        height -> Nullable<Int4>,
        asset_id -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_2 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        recipient_address -> Varchar,
        recipient_alias -> Nullable<Varchar>,
        amount -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_3 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        asset_name -> Varchar,
        description -> Varchar,
        quantity -> Int8,
        decimals -> Int2,
        reissuable -> Bool,
        script -> Nullable<Varchar>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_4 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        amount -> Int8,
        recipient_address -> Varchar,
        recipient_alias -> Nullable<Varchar>,
        fee_asset_id -> Varchar,
        attachment -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_5 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        quantity -> Int8,
        reissuable -> Bool,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_6 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        asset_id -> Varchar,
        amount -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_7 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        order1 -> Jsonb,
        order2 -> Jsonb,
        amount -> Int8,
        price -> Int8,
        amount_asset_id -> Varchar,
        price_asset_id -> Varchar,
        buy_matcher_fee -> Int8,
        sell_matcher_fee -> Int8,
        fee_asset_id -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_8 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        recipient_address -> Varchar,
        recipient_alias -> Nullable<Varchar>,
        amount -> Int8,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    txs_9 (uid) {
        uid -> Int8,
        tx_type -> Int2,
        sender -> Varchar,
        sender_public_key -> Varchar,
        time_stamp -> Timestamptz,
        height -> Int4,
        id -> Varchar,
        signature -> Nullable<Varchar>,
        proofs -> Nullable<Array<Nullable<Text>>>,
        tx_version -> Nullable<Int2>,
        fee -> Int8,
        status -> Varchar,
        block_uid -> Int8,
        lease_tx_uid -> Nullable<Int8>,
    }
}

diesel::table! {
    use diesel::sql_types::*;

    waves_data (quantity) {
        height -> Nullable<Int4>,
        quantity -> Numeric,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    asset_origins,
    asset_tickers,
    asset_updates,
    assets_metadata,
    blocks_microblocks,
    candles,
    pairs,
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
    txs_18,
    txs_18_args,
    txs_18_payment,
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
