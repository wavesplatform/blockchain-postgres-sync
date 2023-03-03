pub mod convert;

use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;
use serde_json::Value;

type TxUid = i64;
type TxHeight = i32;
type TxType = i16;
type TxId = String;
type TxTimeStamp = NaiveDateTime;
type TxSignature = Option<String>;
type TxFee = i64;
type TxProofs = Option<Vec<String>>;
type TxVersion = Option<i16>;
type TxSender = String;
type TxSenderPubKey = String;
type TxStatus = String;
type TxBlockUid = i64;

/// Genesis
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_1)]
pub struct Tx1 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: Option<TxSender>,
    pub sender_public_key: Option<TxSenderPubKey>,
    pub status: TxStatus,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

/// Payment
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_2)]
pub struct Tx2 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

/// Issue
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_3)]
pub struct Tx3 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
    pub quantity: i64,
    pub decimals: i16,
    pub reissuable: bool,
    pub script: Option<String>,
}

/// Transfer
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_4)]
pub struct Tx4 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub amount: i64,
    pub asset_id: String,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub fee_asset_id: String,
    pub attachment: String,
}

/// Reissue
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_5)]
pub struct Tx5 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub quantity: i64,
    pub reissuable: bool,
}

/// Burn
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_6)]
pub struct Tx6 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub amount: i64,
}

/// Exchange
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_7)]
pub struct Tx7 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub order1: Value,
    pub order2: Value,
    pub amount_asset_id: String,
    pub price_asset_id: String,
    pub amount: i64,
    pub price: i64,
    pub buy_matcher_fee: i64,
    pub sell_matcher_fee: i64,
    pub fee_asset_id: String,
}

/// Lease
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_8)]
pub struct Tx8 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

/// LeaseCancel
#[derive(Clone, Debug)]
pub struct Tx9Partial {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub lease_id: Option<String>,
}

/// LeaseCancel
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_9)]
pub struct Tx9 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub lease_tx_uid: Option<i64>,
}

impl From<(&Tx9Partial, Option<i64>)> for Tx9 {
    fn from((tx, lease_tx_uid): (&Tx9Partial, Option<i64>)) -> Self {
        let tx = tx.clone();
        Self {
            uid: tx.uid,
            height: tx.height,
            tx_type: tx.tx_type,
            id: tx.id,
            time_stamp: tx.time_stamp,
            signature: tx.signature,
            fee: tx.fee,
            proofs: tx.proofs,
            tx_version: tx.tx_version,
            sender: tx.sender,
            sender_public_key: tx.sender_public_key,
            status: tx.status,
            lease_tx_uid: tx.lease_id.and(lease_tx_uid),
            block_uid: tx.block_uid,
        }
    }
}

/// CreateAlias
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_10)]
pub struct Tx10 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub alias: String,
}

/// MassTransfer
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_11)]
pub struct Tx11 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub attachment: String,
}

/// MassTransfer
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_11_transfers)]
pub struct Tx11Transfers {
    pub tx_uid: TxUid,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
    pub position_in_tx: i16,
    pub height: TxHeight,
}

/// MassTransfer
#[derive(Clone, Debug)]
pub struct Tx11Combined {
    pub tx: Tx11,
    pub transfers: Vec<Tx11Transfers>,
}

/// DataTransaction
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_12)]
pub struct Tx12 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
}

/// DataTransaction
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_12_data)]
pub struct Tx12Data {
    pub tx_uid: TxUid,
    pub data_key: String,
    pub data_type: Option<String>,
    pub data_value_integer: Option<i64>,
    pub data_value_boolean: Option<bool>,
    pub data_value_binary: Option<String>,
    pub data_value_string: Option<String>,
    pub position_in_tx: i16,
    pub height: TxHeight,
}

/// DataTransaction
#[derive(Clone, Debug)]
pub struct Tx12Combined {
    pub tx: Tx12,
    pub data: Vec<Tx12Data>,
}

/// SetScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_13)]
pub struct Tx13 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub script: Option<String>,
}

/// SponsorFee
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_14)]
pub struct Tx14 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub min_sponsored_asset_fee: Option<i64>,
}

/// SetAssetScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_15)]
pub struct Tx15 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub script: Option<String>,
}

/// InvokeScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_16)]
pub struct Tx16 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub dapp_address: String,
    pub dapp_alias: Option<String>,
    pub function_name: Option<String>,
    pub fee_asset_id: String,
}

/// InvokeScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_16_args)]
pub struct Tx16Args {
    pub tx_uid: TxUid,
    pub arg_type: String,
    pub arg_value_integer: Option<i64>,
    pub arg_value_boolean: Option<bool>,
    pub arg_value_binary: Option<String>,
    pub arg_value_string: Option<String>,
    pub arg_value_list: Option<Value>,
    pub position_in_args: i16,
    pub height: TxHeight,
}

/// InvokeScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_16_payment)]
pub struct Tx16Payment {
    pub tx_uid: TxUid,
    pub amount: i64,
    pub position_in_payment: i16,
    pub height: TxHeight,
    pub asset_id: String,
}

/// InvokeScript
#[derive(Clone, Debug)]
pub struct Tx16Combined {
    pub tx: Tx16,
    pub args: Vec<Tx16Args>,
    pub payments: Vec<Tx16Payment>,
}

/// UpdateAssetInfo
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_17)]
pub struct Tx17 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
}

/// Ethereum
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_18)]
pub struct Tx18 {
    pub uid: TxUid,
    pub height: TxHeight,
    pub tx_type: TxType,
    pub id: TxId,
    pub time_stamp: TxTimeStamp,
    pub signature: TxSignature,
    pub fee: TxFee,
    pub proofs: TxProofs,
    pub tx_version: TxVersion,
    pub block_uid: TxBlockUid,
    pub sender: TxSender,
    pub sender_public_key: TxSenderPubKey,
    pub status: TxStatus,
    pub payload: Vec<u8>,
    pub function_name: Option<String>,
}

/// Ethereum InvokeScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_18_args)]
pub struct Tx18Args {
    pub tx_uid: TxUid,
    pub arg_type: String,
    pub arg_value_integer: Option<i64>,
    pub arg_value_boolean: Option<bool>,
    pub arg_value_binary: Option<String>,
    pub arg_value_string: Option<String>,
    pub arg_value_list: Option<Value>,
    pub position_in_args: i16,
    pub height: TxHeight,
}

/// Ethereum InvokeScript
#[derive(Clone, Debug, Insertable)]
#[diesel(table_name = txs_18_payment)]
pub struct Tx18Payment {
    pub tx_uid: TxUid,
    pub amount: i64,
    pub position_in_payment: i16,
    pub height: TxHeight,
    pub asset_id: String,
}

/// Ethereum
#[derive(Clone, Debug)]
pub struct Tx18Combined {
    pub tx: Tx18,
    pub args: Vec<Tx18Args>,
    pub payments: Vec<Tx18Payment>,
}
