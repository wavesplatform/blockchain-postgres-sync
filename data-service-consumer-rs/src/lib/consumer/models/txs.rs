use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;
use serde_json::Value;

type Height = i32;
type TxType = i16;
type Id = String;
type TimeStamp = NaiveDateTime;
type Signature = Option<String>;
type Fee = i64;
type Proofs = Option<Vec<String>>;
type TxVersion = Option<i16>;
type Sender = String;
type SenderPubKey = String;
type Status = String;

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs"]
pub struct Tx {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Option<Sender>,
    pub sender_public_key: Option<SenderPubKey>,
    pub status: Status,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_1"]
pub struct Tx1 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient: String,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_2"]
pub struct Tx2 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient: String,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_3"]
pub struct Tx3 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
    pub quantity: i64,
    pub decimals: i16,
    pub reissuable: bool,
    pub script: Option<String>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_4"]
pub struct Tx4 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub fee_asset: String,
    pub attachment: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_5"]
pub struct Tx5 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub quantity: i64,
    pub reissuable: bool,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_6"]
pub struct Tx6 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_7"]
pub struct Tx7 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub order1: Value,
    pub order2: Value,
    pub amount_asset: String,
    pub price_asset: String,
    pub amount: i64,
    pub price: i64,
    pub buy_matcher_fee: i64,
    pub sell_matcher_fee: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_8"]
pub struct Tx8 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient: String,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_9"]
pub struct Tx9 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub lease_id: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_10"]
pub struct Tx10 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub alias: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_11"]
pub struct Tx11 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub attachment: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_11_transfers"]
pub struct Tx11Transfers {
    pub tx_id: String,
    pub recipient: String,
    pub amount: i64,
    pub position_in_tx: i16,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_12"]
pub struct Tx12 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_12_data"]
pub struct Tx12Data {
    pub tx_id: String,
    pub data_key: String,
    pub data_type: Option<String>,
    pub data_value_integer: Option<i64>,
    pub data_value_boolean: Option<bool>,
    pub data_value_binary: Option<String>,
    pub data_value_string: Option<String>,
    pub position_in_tx: i16,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_13"]
pub struct Tx13 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub script: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_14"]
pub struct Tx14 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub min_sponsored_asset_fee: Option<i64>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_15"]
pub struct Tx15 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub script: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16"]
pub struct Tx16 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub dapp: String,
    pub function_name: Option<String>,
    pub fee_asset_id: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16_args"]
pub struct Tx16Args {
    pub tx_id: String,
    pub arg_type: String,
    pub arg_value_integer: Option<i64>,
    pub arg_value_boolean: Option<bool>,
    pub arg_value_binary: Option<String>,
    pub arg_value_string: Option<String>,
    pub arg_value_list: Option<Value>,
    pub position_in_args: i16,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16_payment"]
pub struct Tx16Payment {
    pub tx_id: String,
    pub amount: i64,
    pub asset_id: Option<String>,
    pub position_in_payment: i16,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_17"]
pub struct Tx17 {
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
}
