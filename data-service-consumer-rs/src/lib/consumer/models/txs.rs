use crate::error::Error;
use crate::models::{DataEntryTypeValue, Order};
use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;
use serde_json::{json, Value};
use waves_protobuf_schemas::waves::{
    data_transaction_data::data_entry::Value as DataValue,
    events::{
        transaction_metadata::{ethereum_metadata::Action as EthAction, *},
        TransactionMetadata,
    },
    invoke_script_result::call::argument::Value as InvokeScriptArgValue,
    signed_transaction::Transaction,
    transaction::Data,
    Amount, SignedTransaction,
};

type Uid = i64;
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

pub enum Tx {
    Genesis(Tx1),
    Payment(Tx2),
    Issue(Tx3),
    Transfer(Tx4),
    Reissue(Tx5),
    Burn(Tx6),
    Exchange(Tx7),
    Lease(Tx8),
    LeaseCancel(Tx9Partial),
    CreateAlias(Tx10),
    MassTransfer(Tx11Combined),
    DataTransaction(Tx12Combined),
    SetScript(Tx13),
    SponsorFee(Tx14),
    SetAssetScript(Tx15),
    InvokeScript(Tx16Combined),
    UpdateAssetInfo(Tx17),
    Ethereum(Tx18),
}

pub struct TxUidGenerator {
    multiplier: usize,
    last_height: usize,
    last_id: usize,
}

impl TxUidGenerator {
    pub fn new(multiplier: Option<usize>) -> Self {
        Self {
            multiplier: multiplier.unwrap_or(0),
            last_height: 0,
            last_id: 0,
        }
    }

    pub fn maybe_update_height(&mut self, height: usize) {
        if self.last_height < height {
            self.last_height = height;
            self.last_id = 0;
        }
    }

    pub fn next(&mut self) -> usize {
        let result = self.last_height * self.multiplier + self.last_id;
        self.last_id += 1;
        result
    }
}

impl
    TryFrom<(
        &SignedTransaction,
        &Id,
        Height,
        &TransactionMetadata,
        &mut TxUidGenerator,
        i64,
    )> for Tx
{
    type Error = Error;

    fn try_from(
        (tx, id, height, meta, ugen, block_uid): (
            &SignedTransaction,
            &Id,
            Height,
            &TransactionMetadata,
            &mut TxUidGenerator,
            i64,
        ),
    ) -> Result<Self, Self::Error> {
        let into_b58 = |b: &[u8]| bs58::encode(b).into_string();
        let into_prefixed_b64 = |b: &[u8]| String::from("base64:") + &base64::encode(b);
        let sanitize_str = |s: &String| s.replace("\x00", "");
        let parse_attachment = |a: &Vec<u8>| {
            sanitize_str(&String::from_utf8(a.to_owned()).unwrap_or_else(|_| into_b58(a)))
        };

        let (tx, proofs) = match tx {
            SignedTransaction {
                transaction: Some(tx),
                proofs,
            } => (tx, proofs),
            _ => {
                return Err(Error::IncosistDataError(format!(
                    "No transaction data in id={id}, height={height}",
                )))
            }
        };
        let uid = ugen.next() as i64;
        let id = id.to_owned();
        let proofs = proofs.iter().map(|p| into_b58(p)).collect::<Vec<_>>();
        let signature = proofs.get(0).map(ToOwned::to_owned);
        let proofs = Some(proofs);

        let mut status = String::from("succeeded");
        if let Some(
            Metadata::Ethereum(EthereumMetadata {
                action: Some(EthAction::Invoke(ref m)),
                ..
            })
            | Metadata::InvokeScript(ref m),
        ) = meta.metadata
        {
            if let Some(ref result) = m.result {
                if let Some(ref err) = result.error_message {
                    status = err.text.clone();
                }
            }
        }

        let sender = into_b58(&meta.sender_address);

        let tx = match tx {
            Transaction::WavesTransaction(t) => t,
            Transaction::EthereumTransaction(t) => {
                let meta = if let Some(Metadata::Ethereum(ref m)) = meta.metadata {
                    m
                } else {
                    unreachable!()
                };
                return Ok(Tx::Ethereum(Tx18 {
                    uid,
                    height,
                    tx_type: 18,
                    id,
                    time_stamp: NaiveDateTime::from_timestamp(meta.timestamp / 1000, 0),
                    signature,
                    fee: meta.fee,
                    proofs,
                    tx_version: Some(1),
                    sender,
                    sender_public_key: into_b58(&meta.sender_public_key),
                    status,
                    payload: t.clone(),
                    block_uid,
                }));
            }
        };
        let tx_data = tx.data.as_ref().ok_or_else(|| {
            Error::IncosistDataError(format!(
                "No inner transaction data in id={id}, height={height}",
            ))
        })?;
        let time_stamp = NaiveDateTime::from_timestamp(tx.timestamp / 1000, 0);
        let fee = tx.fee.clone();
        let (fee, fee_asset_id) = match fee {
            Some(f) => (f.amount, f.asset_id.to_vec()),
            None => (0, b"WAVES".to_vec()),
        };
        let tx_version = Some(tx.version as i16);
        let sender_public_key = into_b58(tx.sender_public_key.as_ref());

        Ok(match tx_data {
            Data::Genesis(t) => Tx::Genesis(Tx1 {
                uid,
                height,
                tx_type: 1,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key: if !sender_public_key.is_empty() {
                    Some(sender_public_key)
                } else {
                    None
                },
                status,
                recipient_address: String::from("TODO"),
                recipient_alias: None,
                amount: t.amount,
                block_uid,
            }),
            Data::Payment(t) => Tx::Payment(Tx2 {
                uid,
                height,
                tx_type: 2,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                recipient_address: String::from("TODO"),
                recipient_alias: None,
                amount: t.amount,
                block_uid,
            }),
            Data::Issue(t) => Tx::Issue(Tx3 {
                uid,
                height,
                tx_type: 3,
                id: id.clone(),
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                asset_id: id,
                asset_name: sanitize_str(&t.name),
                description: sanitize_str(&t.description),
                quantity: t.amount,
                decimals: t.decimals as i16,
                reissuable: t.reissuable,
                script: if !t.script.is_empty() {
                    Some(into_prefixed_b64(&t.script))
                } else {
                    None
                },
                block_uid,
            }),
            Data::Transfer(t) => {
                let Amount { asset_id, amount } = t.amount.as_ref().unwrap();
                Tx::Transfer(Tx4 {
                    uid,
                    height,
                    tx_type: 4,
                    id,
                    time_stamp,
                    signature,
                    fee,
                    proofs,
                    tx_version,
                    sender,
                    sender_public_key,
                    status,
                    asset_id: into_b58(asset_id),
                    fee_asset_id: into_b58(&fee_asset_id),
                    amount: *amount,
                    attachment: parse_attachment(&t.attachment),
                    recipient_address: if let Some(Metadata::Transfer(ref m)) = meta.metadata {
                        into_b58(&m.recipient_address)
                    } else {
                        unreachable!()
                    },
                    recipient_alias: None,
                    block_uid,
                })
            }
            Data::Reissue(t) => {
                let Amount { asset_id, amount } = t.asset_amount.as_ref().unwrap();
                Tx::Reissue(Tx5 {
                    uid,
                    height,
                    tx_type: 5,
                    id,
                    time_stamp,
                    signature,
                    fee,
                    proofs,
                    tx_version,
                    sender,
                    sender_public_key,
                    status,
                    asset_id: into_b58(asset_id),
                    quantity: *amount,
                    reissuable: t.reissuable,
                    block_uid,
                })
            }
            Data::Burn(t) => {
                let Amount { asset_id, amount } = t.asset_amount.as_ref().unwrap();
                Tx::Burn(Tx6 {
                    uid,
                    height,
                    tx_type: 6,
                    id,
                    time_stamp,
                    signature,
                    fee,
                    proofs,
                    tx_version,
                    sender,
                    sender_public_key,
                    status,
                    asset_id: into_b58(asset_id),
                    amount: *amount,
                    block_uid,
                })
            }
            Data::Exchange(t) => Tx::Exchange(Tx7 {
                uid,
                height,
                tx_type: 7,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                order1: serde_json::to_value(Order::from(&t.orders[0])).unwrap(),
                order2: serde_json::to_value(Order::from(&t.orders[1])).unwrap(),
                amount_asset_id: into_b58(&t.orders[0].clone().asset_pair.unwrap().amount_asset_id),
                price_asset_id: into_b58(&t.orders[0].clone().asset_pair.unwrap().price_asset_id),
                amount: t.amount,
                price: t.price,
                buy_matcher_fee: t.buy_matcher_fee,
                sell_matcher_fee: t.sell_matcher_fee,
                fee_asset_id: into_b58(&fee_asset_id),
                block_uid,
            }),
            Data::Lease(t) => Tx::Lease(Tx8 {
                uid,
                height,
                tx_type: 8,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                amount: t.amount,
                recipient_address: if let Some(Metadata::Lease(ref m)) = meta.metadata {
                    into_b58(&m.recipient_address)
                } else {
                    unreachable!()
                },
                recipient_alias: None,
                block_uid,
            }),
            Data::LeaseCancel(t) => Tx::LeaseCancel(Tx9Partial {
                uid,
                height,
                tx_type: 9,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                lease_id: if !t.lease_id.is_empty() {
                    Some(into_b58(&t.lease_id))
                } else {
                    None
                },
                block_uid,
            }),
            Data::CreateAlias(t) => Tx::CreateAlias(Tx10 {
                uid,
                height,
                tx_type: 10,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                alias: t.alias.clone(),
                block_uid,
            }),
            Data::MassTransfer(t) => Tx::MassTransfer(Tx11Combined {
                tx: Tx11 {
                    uid,
                    height,
                    tx_type: 11,
                    id,
                    time_stamp,
                    signature,
                    fee,
                    proofs,
                    tx_version,
                    sender,
                    sender_public_key,
                    status,
                    asset_id: into_b58(&t.asset_id),
                    attachment: parse_attachment(&t.attachment),
                    block_uid,
                },
                transfers: t
                    .transfers
                    .iter()
                    .zip(if let Some(Metadata::MassTransfer(ref m)) = meta.metadata {
                        &m.recipients_addresses
                    } else {
                        unreachable!()
                    })
                    .enumerate()
                    .map(|(i, (tr, rcp_addr))| Tx11Transfers {
                        tx_uid: uid,
                        recipient_address: into_b58(rcp_addr),
                        recipient_alias: None,
                        amount: tr.amount,
                        position_in_tx: i as i16,
                        height,
                    })
                    .collect(),
            }),
            Data::DataTransaction(t) => Tx::DataTransaction(Tx12Combined {
                tx: Tx12 {
                    uid,
                    height,
                    tx_type: 12,
                    id,
                    time_stamp,
                    signature,
                    fee,
                    proofs,
                    tx_version,
                    sender,
                    sender_public_key,
                    status,
                    block_uid,
                },
                data: t
                    .data
                    .iter()
                    .enumerate()
                    .map(|(i, d)| {
                        let (v_type, v_int, v_bool, v_bin, v_str) = match &d.value {
                            Some(DataValue::IntValue(v)) => {
                                (Some("integer"), Some(v.to_owned()), None, None, None)
                            }
                            Some(DataValue::BoolValue(v)) => {
                                (Some("boolean"), None, Some(v.to_owned()), None, None)
                            }
                            Some(DataValue::BinaryValue(v)) => {
                                (Some("binary"), None, None, Some(v.to_owned()), None)
                            }
                            Some(DataValue::StringValue(v)) => {
                                (Some("string"), None, None, None, Some(v.to_owned()))
                            }
                            _ => (None, None, None, None, None),
                        };
                        Tx12Data {
                            tx_uid: uid,
                            data_key: sanitize_str(&d.key),
                            data_type: v_type.map(String::from),
                            data_value_integer: v_int,
                            data_value_boolean: v_bool,
                            data_value_binary: v_bin.map(|b| into_prefixed_b64(&b)),
                            data_value_string: v_str.map(|s| sanitize_str(&s)),
                            position_in_tx: i as i16,
                            height,
                        }
                    })
                    .collect(),
            }),
            Data::SetScript(t) => Tx::SetScript(Tx13 {
                uid,
                height,
                tx_type: 13,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                script: into_b58(&t.script),
                block_uid,
            }),
            Data::SponsorFee(t) => Tx::SponsorFee(Tx14 {
                uid,
                height,
                tx_type: 14,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                asset_id: into_b58(&t.min_fee.as_ref().unwrap().asset_id.clone()),
                min_sponsored_asset_fee: t.min_fee.as_ref().map(|f| f.amount),
                block_uid,
            }),
            Data::SetAssetScript(t) => Tx::SetAssetScript(Tx15 {
                uid,
                height,
                tx_type: 15,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                asset_id: into_b58(&t.asset_id),
                script: into_prefixed_b64(&t.script),
                block_uid,
            }),
            Data::InvokeScript(t) => {
                let meta = if let Some(Metadata::InvokeScript(ref m)) = meta.metadata {
                    m
                } else {
                    unreachable!()
                };
                Tx::InvokeScript(Tx16Combined {
                    tx: Tx16 {
                        uid,
                        height,
                        tx_type: 16,
                        id,
                        time_stamp,
                        signature,
                        fee,
                        proofs,
                        tx_version,
                        sender,
                        sender_public_key,
                        status,
                        function_name: Some(meta.function_name.clone()),
                        fee_asset_id: into_b58(&tx.fee.as_ref().unwrap().asset_id.clone()),
                        dapp_address: into_b58(&meta.d_app_address),
                        dapp_alias: None,
                        block_uid,
                    },
                    args: meta
                        .arguments
                        .iter()
                        .filter_map(|arg| arg.value.as_ref())
                        .enumerate()
                        .map(|(i, arg)| {
                            let (v_type, v_int, v_bool, v_bin, v_str, v_list) = match &arg {
                                InvokeScriptArgValue::IntegerValue(v) => {
                                    ("integer", Some(v.to_owned()), None, None, None, None)
                                }
                                InvokeScriptArgValue::BooleanValue(v) => {
                                    ("boolean", None, Some(v.to_owned()), None, None, None)
                                }
                                InvokeScriptArgValue::BinaryValue(v) => {
                                    ("binary", None, None, Some(v.to_owned()), None, None)
                                }
                                InvokeScriptArgValue::StringValue(v) => {
                                    ("string", None, None, None, Some(v.to_owned()), None)
                                }
                                InvokeScriptArgValue::List(_) => (
                                    "list",
                                    None,
                                    None,
                                    None,
                                    None,
                                    Some(json!(DataEntryTypeValue::from(arg))["value"].clone()),
                                ),
                                InvokeScriptArgValue::CaseObj(_) => {
                                    ("case", None, None, None, None, None)
                                }
                            };
                            Tx16Args {
                                tx_uid: uid,
                                arg_type: v_type.to_string(),
                                arg_value_integer: v_int,
                                arg_value_boolean: v_bool,
                                arg_value_binary: v_bin.map(|v| into_prefixed_b64(&v)),
                                arg_value_string: v_str,
                                arg_value_list: v_list,
                                position_in_args: i as i16,
                                height,
                            }
                        })
                        .collect(),
                    payments: t
                        .payments
                        .iter()
                        .enumerate()
                        .map(|(i, p)| Tx16Payment {
                            tx_uid: uid,
                            amount: p.amount,
                            position_in_payment: i as i16,
                            height,
                            asset_id: into_b58(&p.asset_id),
                        })
                        .collect(),
                })
            }
            Data::UpdateAssetInfo(t) => Tx::UpdateAssetInfo(Tx17 {
                uid,
                height,
                tx_type: 17,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                asset_id: into_b58(&t.asset_id),
                asset_name: sanitize_str(&t.name),
                description: sanitize_str(&t.description),
                block_uid,
            }),
            Data::InvokeExpression(_t) => unimplemented!(),
        })
    }
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_1"]
pub struct Tx1 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: Option<SenderPubKey>,
    pub status: Status,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_2"]
pub struct Tx2 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_3"]
pub struct Tx3 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
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
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub amount: i64,
    pub asset_id: String,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub fee_asset_id: String,
    pub attachment: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_5"]
pub struct Tx5 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
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
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub amount: i64,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_7"]
pub struct Tx7 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
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

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_8"]
pub struct Tx8 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
}

#[derive(Clone, Debug)]
pub struct Tx9Partial {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub lease_id: Option<String>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_9"]
pub struct Tx9 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
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

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_10"]
pub struct Tx10 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub alias: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_11"]
pub struct Tx11 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub attachment: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_11_transfers"]
pub struct Tx11Transfers {
    pub tx_uid: i64,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
    pub position_in_tx: i16,
    pub height: i32,
}

#[derive(Clone, Debug)]
pub struct Tx11Combined {
    pub tx: Tx11,
    pub transfers: Vec<Tx11Transfers>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_12"]
pub struct Tx12 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_12_data"]
pub struct Tx12Data {
    pub tx_uid: i64,
    pub data_key: String,
    pub data_type: Option<String>,
    pub data_value_integer: Option<i64>,
    pub data_value_boolean: Option<bool>,
    pub data_value_binary: Option<String>,
    pub data_value_string: Option<String>,
    pub position_in_tx: i16,
    pub height: i32,
}

#[derive(Clone, Debug)]
pub struct Tx12Combined {
    pub tx: Tx12,
    pub data: Vec<Tx12Data>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_13"]
pub struct Tx13 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub script: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_14"]
pub struct Tx14 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub min_sponsored_asset_fee: Option<i64>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_15"]
pub struct Tx15 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub script: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16"]
pub struct Tx16 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub dapp_address: String,
    pub dapp_alias: Option<String>,
    pub function_name: Option<String>,
    pub fee_asset_id: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16_args"]
pub struct Tx16Args {
    pub tx_uid: i64,
    pub arg_type: String,
    pub arg_value_integer: Option<i64>,
    pub arg_value_boolean: Option<bool>,
    pub arg_value_binary: Option<String>,
    pub arg_value_string: Option<String>,
    pub arg_value_list: Option<Value>,
    pub position_in_args: i16,
    pub height: i32,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_16_payment"]
pub struct Tx16Payment {
    pub tx_uid: i64,
    pub amount: i64,
    pub position_in_payment: i16,
    pub height: i32,
    pub asset_id: String,
}

#[derive(Clone, Debug)]
pub struct Tx16Combined {
    pub tx: Tx16,
    pub args: Vec<Tx16Args>,
    pub payments: Vec<Tx16Payment>,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_17"]
pub struct Tx17 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
}

#[derive(Clone, Debug, Insertable)]
#[table_name = "txs_18"]
pub struct Tx18 {
    pub uid: Uid,
    pub height: Height,
    pub tx_type: TxType,
    pub id: Id,
    pub time_stamp: TimeStamp,
    pub signature: Signature,
    pub fee: Fee,
    pub proofs: Proofs,
    pub tx_version: TxVersion,
    pub block_uid: i64,
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub payload: Vec<u8>,
}
