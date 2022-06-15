use crate::waves::{WAVES_ID, WAVES_NAME, WAVES_PRECISION};
use chrono::{DateTime, Utc};
use serde::Serialize;
use waves_protobuf_schemas::waves::{order::Sender as SenderPb, Order as OrderPb};

#[derive(Clone, Debug)]
pub struct BaseAssetInfoUpdate {
    pub id: String,
    pub issuer: String,
    pub precision: i32,
    pub nft: bool,
    pub updated_at: DateTime<Utc>,
    pub update_height: i32,
    pub name: String,
    pub description: String,
    pub script: Option<Vec<u8>>,
    pub quantity: i64,
    pub reissuable: bool,
    pub min_sponsored_fee: Option<i64>,
    pub tx_id: String,
}

impl BaseAssetInfoUpdate {
    pub fn waves_update(height: i32, time_stamp: DateTime<Utc>, quantity: i64) -> Self {
        Self {
            id: WAVES_ID.to_owned(),
            issuer: "".to_owned(),
            precision: WAVES_PRECISION.to_owned(),
            nft: false,
            updated_at: time_stamp,
            update_height: height,
            name: WAVES_NAME.to_owned(),
            description: "".to_owned(),
            script: None,
            quantity,
            reissuable: false,
            min_sponsored_fee: None,
            tx_id: String::new(),
        }
    }
}

#[derive(Debug)]
pub enum DataEntryTypeValue {
    BinVal(String),
    BoolVal(bool),
    IntVal(i64),
    StrVal(String),
}

#[derive(Serialize)]
pub struct Order {
    pub chain_id: i32,
    pub matcher_public_key: Vec<u8>,
    pub asset_pair: Option<AssetPair>,
    pub order_side: i32,
    pub amount: i64,
    pub price: i64,
    pub timestamp: i64,
    pub expiration: i64,
    pub matcher_fee: Option<Amount>,
    pub version: i32,
    pub proofs: Vec<Vec<u8>>,
    pub price_mode: i32,
    pub sender: Option<Sender>,
}

impl From<&OrderPb> for Order {
    fn from(o: &OrderPb) -> Self {
        let o = o.clone();
        Self {
            chain_id: o.chain_id,
            matcher_public_key: o.matcher_public_key,
            asset_pair: o.asset_pair.map(|p| AssetPair {
                amount_asset_id: p.amount_asset_id,
                price_asset_id: p.price_asset_id,
            }),
            order_side: o.order_side,
            amount: o.amount,
            price: o.price,
            timestamp: o.timestamp,
            expiration: o.expiration,
            matcher_fee: o.matcher_fee.map(|f| Amount {
                asset_id: f.asset_id,
                amount: f.amount,
            }),
            version: o.version,
            proofs: o.proofs,
            price_mode: o.price_mode,
            sender: o.sender.map(|s| match s {
                SenderPb::Eip712Signature(v) => Sender::Eip712Signature(v),
                SenderPb::SenderPublicKey(v) => Sender::SenderPublicKey(v),
            }),
        }
    }
}

#[derive(Serialize)]
pub struct AssetPair {
    pub amount_asset_id: Vec<u8>,
    pub price_asset_id: Vec<u8>,
}

#[derive(Serialize)]
pub struct Amount {
    pub asset_id: Vec<u8>,
    pub amount: i64,
}

#[derive(Serialize)]
pub enum Sender {
    SenderPublicKey(Vec<u8>),
    Eip712Signature(Vec<u8>),
}
