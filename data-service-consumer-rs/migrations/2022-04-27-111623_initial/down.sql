DROP TABLE IF EXISTS asset_origins;
DROP TABLE IF EXISTS asset_updates;
DROP TABLE IF EXISTS blocks_microblocks;
DROP TABLE IF EXISTS assets_names_map;
DROP TABLE IF EXISTS assets_metadata;
DROP TABLE IF EXISTS tickers;
DROP TABLE IF EXISTS candles;
DROP TABLE IF EXISTS pairs;
DROP TABLE IF EXISTS waves_data;
DROP TABLE IF EXISTS txs_1;
DROP TABLE IF EXISTS txs_2;
DROP TABLE IF EXISTS txs_3;
DROP TABLE IF EXISTS txs_4;
DROP TABLE IF EXISTS txs_5;
DROP TABLE IF EXISTS txs_6;
DROP TABLE IF EXISTS txs_7;
DROP TABLE IF EXISTS txs_8;
DROP TABLE IF EXISTS txs_9;
DROP TABLE IF EXISTS txs_10;
DROP TABLE IF EXISTS txs_11_transfers;
DROP TABLE IF EXISTS txs_11;
DROP TABLE IF EXISTS txs_12_data;
DROP TABLE IF EXISTS txs_12;
DROP TABLE IF EXISTS txs_13;
DROP TABLE IF EXISTS txs_14;
DROP TABLE IF EXISTS txs_15;
DROP TABLE IF EXISTS txs_16_args;
DROP TABLE IF EXISTS txs_16_payment;
DROP TABLE IF EXISTS txs_16;
DROP TABLE IF EXISTS txs_17;
DROP TABLE IF EXISTS txs_18;
DROP TABLE IF EXISTS txs CASCADE;

DROP INDEX IF EXISTS candles_max_height_index;
DROP INDEX IF EXISTS candles_amount_price_ids_matcher_time_start_partial_1m_idx;
DROP INDEX IF EXISTS txs_height_idx;
DROP INDEX IF EXISTS txs_id_idx;
DROP INDEX IF EXISTS txs_sender_uid_idx;
DROP INDEX IF EXISTS txs_time_stamp_uid_idx;
DROP INDEX IF EXISTS txs_tx_type_idx;
DROP INDEX IF EXISTS txs_10_alias_sender_idx;
DROP INDEX IF EXISTS txs_10_alias_uid_idx;
DROP INDEX IF EXISTS txs_10_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_10_height_idx;
DROP INDEX IF EXISTS txs_10_sender_uid_idx;
DROP INDEX IF EXISTS txs_10_id_idx;
DROP INDEX IF EXISTS txs_11_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_11_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_11_height_idx;
DROP INDEX IF EXISTS txs_11_sender_uid_idx;
DROP INDEX IF EXISTS txs_11_id_idx;
DROP INDEX IF EXISTS txs_11_transfers_height_idx;
DROP INDEX IF EXISTS txs_11_transfers_recipient_address_idx;
DROP INDEX IF EXISTS txs_12_data_data_value_binary_tx_uid_partial_idx;
DROP INDEX IF EXISTS txs_12_data_data_value_boolean_tx_uid_partial_idx;
DROP INDEX IF EXISTS txs_12_data_data_value_integer_tx_uid_partial_idx;
DROP INDEX IF EXISTS txs_12_data_data_value_string_tx_uid_partial_idx;
DROP INDEX IF EXISTS txs_12_data_height_idx;
DROP INDEX IF EXISTS txs_12_data_tx_uid_idx;
DROP INDEX IF EXISTS txs_12_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_12_height_idx;
DROP INDEX IF EXISTS txs_12_sender_uid_idx;
DROP INDEX IF EXISTS txs_12_id_idx;
DROP INDEX IF EXISTS txs_12_data_data_key_tx_uid_idx;
DROP INDEX IF EXISTS txs_12_data_data_type_tx_uid_idx;
DROP INDEX IF EXISTS txs_13_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_13_height_idx;
DROP INDEX IF EXISTS txs_13_md5_script_idx;
DROP INDEX IF EXISTS txs_13_sender_uid_idx;
DROP INDEX IF EXISTS txs_13_id_idx;
DROP INDEX IF EXISTS txs_14_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_14_height_idx;
DROP INDEX IF EXISTS txs_14_sender_uid_idx;
DROP INDEX IF EXISTS txs_14_id_idx;
DROP INDEX IF EXISTS txs_15_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_15_height_idx;
DROP INDEX IF EXISTS txs_15_md5_script_idx;
DROP INDEX IF EXISTS txs_15_sender_uid_idx;
DROP INDEX IF EXISTS txs_15_id_idx;
DROP INDEX IF EXISTS txs_16_dapp_address_uid_idx;
DROP INDEX IF EXISTS txs_16_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_16_height_idx;
DROP INDEX IF EXISTS txs_16_sender_uid_idx;
DROP INDEX IF EXISTS txs_16_id_idx;
DROP INDEX IF EXISTS txs_16_function_name_uid_idx;
DROP INDEX IF EXISTS txs_16_args_height_idx;
DROP INDEX IF EXISTS txs_16_payment_asset_id_idx;
DROP INDEX IF EXISTS txs_16_payment_height_idx;
DROP INDEX IF EXISTS txs_16_dapp_address_function_name_uid_idx;
DROP INDEX IF EXISTS txs_16_sender_time_stamp_uid_idx;
DROP INDEX IF EXISTS txs_17_height_idx;
DROP INDEX IF EXISTS txs_17_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_17_sender_time_stamp_id_idx;
DROP INDEX IF EXISTS txs_17_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_1_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_1_height_idx;
DROP INDEX IF EXISTS txs_1_sender_uid_idx;
DROP INDEX IF EXISTS txs_1_id_idx;
DROP INDEX IF EXISTS txs_2_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_2_height_idx;
DROP INDEX IF EXISTS txs_2_sender_uid_idx;
DROP INDEX IF EXISTS txs_2_id_idx;
DROP INDEX IF EXISTS txs_3_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_3_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_3_height_idx;
DROP INDEX IF EXISTS txs_3_md5_script_idx;
DROP INDEX IF EXISTS txs_3_sender_uid_idx;
DROP INDEX IF EXISTS txs_3_id_idx;
DROP INDEX IF EXISTS txs_4_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_4_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_4_height_uid_idx;
DROP INDEX IF EXISTS txs_4_id_idx;
DROP INDEX IF EXISTS txs_4_recipient_address_uid_idx;
DROP INDEX IF EXISTS txs_4_sender_uid_idx;
DROP INDEX IF EXISTS txs_5_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_5_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_5_height_idx;
DROP INDEX IF EXISTS txs_5_sender_uid_idx;
DROP INDEX IF EXISTS txs_5_id_idx;
DROP INDEX IF EXISTS txs_6_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_6_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_6_height_idx;
DROP INDEX IF EXISTS txs_6_sender_uid_idx;
DROP INDEX IF EXISTS txs_6_id_idx;
DROP INDEX IF EXISTS txs_7_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_7_height_idx;
DROP INDEX IF EXISTS txs_7_sender_uid_idx;
DROP INDEX IF EXISTS txs_7_order_ids_uid_idx;
DROP INDEX IF EXISTS txs_7_id_idx;
DROP INDEX IF EXISTS txs_7_order_senders_uid_idx;
DROP INDEX IF EXISTS txs_7_amount_asset_id_price_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_7_price_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_8_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_8_height_idx;
DROP INDEX IF EXISTS txs_8_recipient_idx;
DROP INDEX IF EXISTS txs_8_recipient_address_uid_idx;
DROP INDEX IF EXISTS txs_8_sender_uid_idx;
DROP INDEX IF EXISTS txs_8_id_idx;
DROP INDEX IF EXISTS txs_9_uid_time_stamp_unique_idx;
DROP INDEX IF EXISTS txs_9_height_idx;
DROP INDEX IF EXISTS txs_9_sender_uid_idx;
DROP INDEX IF EXISTS txs_9_id_idx;
DROP INDEX IF EXISTS waves_data_height_desc_quantity_idx;
DROP INDEX IF EXISTS blocks_time_stamp_height_gist_idx;
DROP INDEX IF EXISTS txs_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_1_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_10_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_11_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_12_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_13_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_14_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_15_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_16_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_17_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_2_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_3_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_4_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_5_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_6_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_7_amount_asset_id_uid_idx;
DROP INDEX IF EXISTS txs_7_order_sender_1_uid_desc_idx;
DROP INDEX IF EXISTS txs_7_order_sender_2_uid_desc_idx;
DROP INDEX IF EXISTS txs_7_time_stamp_gist_idx;
DROP INDEX IF EXISTS txs_7_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_7_uid_height_time_stamp_idx;
DROP INDEX IF EXISTS txs_8_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS txs_9_time_stamp_uid_gist_idx;
DROP INDEX IF EXISTS blocks_microblocks_id_idx;
DROP INDEX IF EXISTS blocks_microblocks_time_stamp_uid_idx;
DROP INDEX IF EXISTS asset_updates_block_uid_idx;
DROP INDEX IF EXISTS asset_updates_to_tsvector_idx;
DROP INDEX IF EXISTS tickers_ticker_idx;

DROP EXTENSION IF EXISTS btree_gin;