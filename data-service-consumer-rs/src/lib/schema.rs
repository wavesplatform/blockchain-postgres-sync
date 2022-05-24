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

    blocks_microblocks (id) {
        uid -> Int8,
        id -> Varchar,
        height -> Int4,
        time_stamp -> Nullable<Timestamptz>,
    }
}

allow_tables_to_appear_in_same_query!(asset_origins, asset_updates, blocks_microblocks,);
