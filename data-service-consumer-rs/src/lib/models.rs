use crate::utils::{escape_unicode_null, into_base58};
use chrono::{DateTime, Utc};
use serde::ser::{SerializeStruct, Serializer};
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
            InvokeScriptArgValue::StringValue(v) => {
                DataEntryTypeValue::String(escape_unicode_null(v))
            }
            InvokeScriptArgValue::BooleanValue(v) => DataEntryTypeValue::Boolean(*v),
            // deep conversion of List
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

#[derive(Debug)]
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
    pub signature: String,
    pub eip712_signature: Option<String>,
    pub price_mode: Option<String>,
}

impl Serialize for Order {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let fields_count = match self.version {
            1..=2 => 15,
            3 => 16,   // + matcher_fee_asset_id
            4.. => 17, // + eip712_signature, price_mode
            v => unreachable!("unknown order version {v}"),
        };
        let mut state = serializer.serialize_struct("Order", fields_count)?;
        state.serialize_field("id", &self.id)?;
        state.serialize_field("version", &self.version)?;
        state.serialize_field("sender", &self.sender)?;
        state.serialize_field("senderPublicKey", &self.sender_public_key)?;
        state.serialize_field("matcherPublicKey", &self.matcher_public_key)?;
        state.serialize_field("assetPair", &self.asset_pair)?;
        state.serialize_field("orderType", &self.order_type)?;
        state.serialize_field("amount", &self.amount)?;
        state.serialize_field("price", &self.price)?;
        state.serialize_field("timestamp", &self.timestamp)?;
        state.serialize_field("expiration", &self.expiration)?;
        state.serialize_field("matcherFee", &self.matcher_fee)?;
        state.serialize_field("proofs", &self.proofs)?;
        state.serialize_field("signature", &self.signature)?;

        if self.version >= 3 {
            state.serialize_field("matcherFeeAssetId", &self.matcher_fee_asset_id)?;
        }

        if self.version >= 4 {
            state.serialize_field("eip712Signature", &self.eip712_signature)?;
            state.serialize_field("priceMode", &self.price_mode)?;
        }
        state.end()
    }
}

impl From<OrderMeta<'_>> for Order {
    fn from(o: OrderMeta) -> Self {
        let OrderMeta {
            order,
            id,
            sender_address,
            sender_public_key,
        } = o;
        let proofs: Vec<String> = order.proofs.iter().map(into_base58).collect();
        let signature = proofs.get(0).cloned().unwrap_or_else(|| String::new());
        Self {
            matcher_public_key: into_base58(&order.matcher_public_key),
            asset_pair: AssetPair {
                amount_asset_id: order
                    .asset_pair
                    .as_ref()
                    .map(|p| &p.amount_asset_id)
                    .and_then(|asset| (asset.len() > 0).then(|| into_base58(asset))),
                price_asset_id: order
                    .asset_pair
                    .as_ref()
                    .map(|p| &p.price_asset_id)
                    .and_then(|asset| (asset.len() > 0).then(|| into_base58(asset))),
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
                .and_then(|asset| (asset.len() > 0).then(|| into_base58(asset))),
            version: order.version,
            proofs,
            sender: into_base58(sender_address),
            id: into_base58(&id),
            sender_public_key: into_base58(&sender_public_key),
            signature,
            eip712_signature: match order.sender {
                Some(SenderPb::Eip712Signature(ref sig)) if order.version >= 4 => {
                    Some(format!("0x{}", hex::encode(sig)))
                }
                _ => None,
            },
            price_mode: match order.price_mode {
                0 => None,
                1 => Some("fixedDecimals".to_string()),
                2 => Some("assetDecimals".to_string()),
                m => unreachable!("unknown order price_mode {m}"),
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
