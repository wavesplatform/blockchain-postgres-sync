use crate::utils::into_b58;
use crate::waves::{WAVES_ID, WAVES_NAME, WAVES_PRECISION};
use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::{json, Value};
use waves_protobuf_schemas::waves::{
    invoke_script_result::call::argument::{List as ListPb, Value as InvokeScriptArgValue},
    order::Sender as SenderPb,
    Order as OrderPb,
};

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

#[derive(Debug, Serialize)]
#[serde(rename_all = "lowercase")]
#[serde(tag = "type", content = "value")]
pub enum DataEntryTypeValue {
    Binary(String),
    Boolean(bool),
    Integer(i64),
    String(String),
    List(Value),
}

impl From<&InvokeScriptArgValue> for DataEntryTypeValue {
    fn from(val: &InvokeScriptArgValue) -> Self {
        match val {
            InvokeScriptArgValue::IntegerValue(v) => DataEntryTypeValue::Integer(*v),
            InvokeScriptArgValue::BinaryValue(v) => {
                DataEntryTypeValue::Binary(format!("base64:{}", base64::encode(v)))
            }
            InvokeScriptArgValue::StringValue(v) => DataEntryTypeValue::String(v.to_owned()),
            InvokeScriptArgValue::BooleanValue(v) => DataEntryTypeValue::Boolean(*v),
            InvokeScriptArgValue::List(v) => DataEntryTypeValue::List(json!(ArgList::from(v))),
            InvokeScriptArgValue::CaseObj(_) => todo!(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct ArgList(pub Vec<DataEntryTypeValue>);

impl From<&ListPb> for ArgList {
    fn from(list: &ListPb) -> Self {
        ArgList(
            list.items
                .iter()
                .filter_map(|i| i.value.as_ref().map(DataEntryTypeValue::from))
                .collect(),
        )
    }
}

pub struct OrderMeta<'o> {
    pub order: &'o OrderPb,
    pub id: &'o [u8],
    pub sender_address: &'o [u8],
    pub sender_public_key: &'o [u8],
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Order {
    pub id: String,
    pub version: i32,
    pub sender: String,
    pub sender_public_key: String,
    pub matcher_public_key: String,
    pub asset_pair: AssetPair,
    pub order_type: OrderType,
    pub amount: i64,
    pub price: i64,
    pub timestamp: i64,
    pub expiration: i64,
    pub matcher_fee: i64,
    pub matcher_fee_asset_id: Option<String>,
    pub proofs: Vec<String>,
    pub signature: Option<String>,
}

impl From<OrderMeta<'_>> for Order {
    fn from(o: OrderMeta) -> Self {
        let OrderMeta {
            order,
            id,
            sender_address,
            sender_public_key,
        } = o;
        Self {
            matcher_public_key: into_b58(&order.matcher_public_key),
            asset_pair: AssetPair {
                amount_asset_id: order
                    .asset_pair
                    .as_ref()
                    .map(|p| &p.amount_asset_id)
                    .and_then(|asset| (asset.len() > 0).then(|| into_b58(asset))),
                price_asset_id: order
                    .asset_pair
                    .as_ref()
                    .map(|p| &p.price_asset_id)
                    .and_then(|asset| (asset.len() > 0).then(|| into_b58(asset))),
            },
            order_type: OrderType::from(order.order_side),
            amount: order.amount,
            price: order.price,
            timestamp: order.timestamp,
            expiration: order.expiration,
            matcher_fee: order.matcher_fee.as_ref().map(|f| f.amount).unwrap_or(0),
            matcher_fee_asset_id: order
                .matcher_fee
                .as_ref()
                .map(|f| &f.asset_id)
                .and_then(|asset| (asset.len() > 0).then(|| into_b58(asset))),
            version: order.version,
            proofs: order.proofs.iter().map(into_b58).collect(),
            sender: into_b58(sender_address),
            id: into_b58(&id),
            sender_public_key: into_b58(&sender_public_key),
            signature: match order.sender {
                Some(SenderPb::Eip712Signature(ref sig)) => Some(format!("0x{}", hex::encode(sig))),
                _ => None,
            },
        }
    }
}

#[derive(Serialize, Debug)]
pub struct AssetPair {
    #[serde(rename = "amountAsset")]
    pub amount_asset_id: Option<String>,
    #[serde(rename = "priceAsset")]
    pub price_asset_id: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum OrderType {
    Buy = 0,
    Sell = 1,
}

impl From<i32> for OrderType {
    fn from(n: i32) -> Self {
        match n {
            0 => OrderType::Buy,
            1 => OrderType::Sell,
            r => panic!("unknown OrderType {r}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use waves_protobuf_schemas::waves::invoke_script_result::call::Argument;

    #[test]
    fn serialize_arg_list() {
        let src = InvokeScriptArgValue::List(ListPb {
            items: vec![
                Argument {
                    value: Some(InvokeScriptArgValue::IntegerValue(5)),
                },
                Argument {
                    value: Some(InvokeScriptArgValue::BinaryValue(b"\x00\x01".to_vec())),
                },
            ],
        });
        let data_value = DataEntryTypeValue::from(&src);
        if matches!(data_value, DataEntryTypeValue::List(_)) {
            let json = json!(data_value);
            let serialized = serde_json::to_string(&json["value"]).unwrap();
            let expected = json!([
                {"type": "integer", "value": 5},
                {"type": "binary", "value": "base64:AAE="},
            ]);
            assert_eq!(serialized, serde_json::to_string(&expected).unwrap());
        } else {
            panic!("Wrong variant: {:?}", src);
        }
    }
}
