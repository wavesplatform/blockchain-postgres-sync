use crate::error::Error;
use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;
use serde_json::Value;
use waves_protobuf_schemas::waves::{
    data_transaction_data::data_entry::Value as DataValue, recipient::Recipient as InnerRecipient,
    signed_transaction::Transaction, transaction::Data, Recipient, SignedTransaction,
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
    LeaseCancel(Tx9),
    CreateAlias(Tx10),
    MassTransfer((Tx11, Vec<Tx11Transfers>)),
    DataTransaction((Tx12, Vec<Tx12Data>)),
    SetScript(Tx13),
    SponsorFee(Tx14),
    SetAssetScript(Tx15),
    InvokeScript((Tx16, Vec<Tx16Args>, Vec<Tx16Payment>)),
    UpdateAssetInfo(Tx17),
    InvokeExpression,
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

impl TryFrom<(SignedTransaction, Id, Height, Vec<u8>, &mut TxUidGenerator)> for Tx {
    type Error = Error;

    fn try_from(
        (tx, id, height, sender, ugen): (
            SignedTransaction,
            Id,
            Height,
            Vec<u8>,
            &mut TxUidGenerator,
        ),
    ) -> Result<Self, Self::Error> {
        let into_b58 = |b| bs58::encode(b).into_string();
        let into_prefixed_b64 = |b| String::from("base64:") + &base64::encode(b);

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
        let tx = match tx {
            Transaction::WavesTransaction(t) => t,
            Transaction::EthereumTransaction(_) => {
                return Err(Error::IncosistDataError(
                    "EthereumTransaction is not supported yet".to_string(),
                ))
            }
        };
        let tx_data = tx.data.ok_or(Error::IncosistDataError(format!(
            "No inner transaction data in id={id}, height={height}",
        )))?;
        let time_stamp = NaiveDateTime::from_timestamp(tx.timestamp / 1000, 0);
        let fee = tx.fee.unwrap().amount;
        let proofs = proofs
            .into_iter()
            .map(|p| String::from_utf8(p).unwrap())
            .collect::<Vec<_>>();
        let signature = proofs.get(0).map(ToOwned::to_owned);
        let proofs = Some(proofs);
        let tx_version = Some(tx.version as i16);
        let sender_public_key = into_b58(tx.sender_public_key);
        let status = String::from("succeeded");
        let sender = into_b58(sender);
        let uid = ugen.next() as i64;

        let parse_attachment = |a| String::from_utf8(a).unwrap_or_else(|_| into_b58(a));
        let parse_recipient = |r: Recipient| match r.recipient.unwrap() {
            InnerRecipient::Alias(a) => a,
            InnerRecipient::PublicKeyHash(p) => into_b58(p),
        };

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
                sender_public_key: if sender_public_key.len() > 0 {
                    Some(sender_public_key)
                } else {
                    None
                },
                status,
                recipient_address: into_b58(t.recipient_address),
                recipient_alias: None,
                amount: t.amount,
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
                recipient_address: into_b58(t.recipient_address),
                recipient_alias: None,
                amount: t.amount,
            }),
            Data::Issue(t) => Tx::Issue(Tx3 {
                uid,
                height,
                tx_type: 3,
                id,
                time_stamp,
                signature,
                fee,
                proofs,
                tx_version,
                sender,
                sender_public_key,
                status,
                //TODO: maybe pick from StateUpdate
                asset_id: todo!(),
                asset_name: t.name,
                description: t.description,
                quantity: t.amount,
                decimals: t.decimals as i16,
                reissuable: t.reissuable,
                script: if t.script.len() > 0 {
                    Some(into_prefixed_b64(t.script))
                } else {
                    None
                },
            }),
            Data::Transfer(t) => Tx::Transfer(Tx4 {
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
                asset_id: into_b58(t.amount.unwrap().asset_id),
                fee_asset_id: into_b58(tx.fee.unwrap().asset_id),
                amount: t.amount.unwrap().amount,
                attachment: parse_attachment(t.attachment),
            }),
            Data::Reissue(t) => Tx::Reissue(Tx5 {
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
                asset_id: into_b58(t.asset_amount.unwrap().asset_id),
                quantity: t.asset_amount.unwrap().amount,
                reissuable: t.reissuable,
            }),
            Data::Burn(t) => Tx::Burn(Tx6 {
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
                asset_id: into_b58(t.asset_amount.unwrap().asset_id),
                amount: t.asset_amount.unwrap().amount,
            }),
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
                //TODO: serialize foreign struct
                order1: serde_json::to_value(t.orders[0]).unwrap(),
                order2: serde_json::to_value(t.orders[1]).unwrap(),
                amount_asset_id: into_b58(t.orders[0].asset_pair.unwrap().amount_asset_id),
                price_asset_id: into_b58(t.orders[0].asset_pair.unwrap().price_asset_id),
                amount: t.amount,
                price: t.price,
                buy_matcher_fee: t.buy_matcher_fee,
                sell_matcher_fee: t.sell_matcher_fee,
                fee_asset_id: into_b58(tx.fee.unwrap().asset_id),
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
                recipient_address: parse_recipient(t.recipient.unwrap()),
                recipient_alias: None,
            }),
            Data::LeaseCancel(t) => Tx::LeaseCancel(Tx9 {
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
                lease_tx_uid: if t.lease_id.len() > 0 {
                    Some(i64::from_be_bytes(&t.lease_id))
                } else {
                    None
                },
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
                alias: t.alias,
            }),
            Data::MassTransfer(t) => {
                let mut ugen = TxUidGenerator::new(None);
                Tx::MassTransfer((
                    Tx11 {
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
                        asset_id: into_b58(t.asset_id),
                        attachment: parse_attachment(t.attachment),
                    },
                    t.transfers
                        .into_iter()
                        .map(|tr| Tx11Transfers {
                            tx_uid: uid,
                            recipient_address: parse_recipient(tr.recipient.unwrap()),
                            //TODO: rework this
                            recipient_alias: None,
                            amount: tr.amount,
                            position_in_tx: ugen.next() as i16,
                            height,
                        })
                        .collect(),
                ))
            }
            Data::DataTransaction(t) => {
                let ugen = TxUidGenerator::new(None);
                Tx::DataTransaction((
                    Tx12 {
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
                    },
                    t.data
                        .into_iter()
                        .map(|d| {
                            let (v_type, v_int, v_bool, v_bin, v_str) = match d.value {
                                Some(DataValue::IntValue(v)) => {
                                    (Some("integer"), Some(v.to_owned()), None, None, None)
                                }
                                Some(DataValue::BoolValue(v)) => {
                                    (Some("boolean"), None, Some(v.to_owned()), None, None)
                                }
                                Some(DataValue::BinaryValue(v)) => {
                                    (Some("integer"), None, None, Some(v.to_owned()), None)
                                }
                                Some(DataValue::StringValue(v)) => {
                                    (Some("string"), None, None, None, Some(v.to_owned()))
                                }
                                _ => (None, None, None, None, None),
                            };
                            Tx12Data {
                                tx_uid: uid,
                                data_key: d.key,
                                data_type: v_type.map(String::from),
                                data_value_integer: v_int,
                                data_value_boolean: v_bool,
                                data_value_binary: v_bin.map(into_prefixed_b64),
                                data_value_string: v_str,
                                position_in_tx: ugen.next() as i16,
                                height,
                            }
                        })
                        .collect(),
                ))
            }
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
                script: into_b58(t.script),
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
                asset_id: into_b58(t.min_fee.unwrap().asset_id),
                min_sponsored_asset_fee: t.min_fee.map(|f| f.amount),
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
                asset_id: into_b58(t.asset_id),
                script: into_prefixed_b64(t.script),
            }),
            Data::InvokeScript(t) => {
                let mut ugen_args = TxUidGenerator::new(None);
                let mut ugen_payments = TxUidGenerator::new(None);
                Tx::InvokeScript((
                    Tx16 {
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
                        function_name: Some(String::from_utf8(t.function_call).unwrap()),
                        fee_asset_id: into_b58(tx.fee.unwrap().asset_id),
                        dapp_address: parse_recipient(t.d_app.unwrap()),
                        dapp_alias: None,
                    },
                    into_iter()
                        .map(|a| Tx16Args {
                            tx_uid: uid,
                            arg_type: todo!(),
                            arg_value_integer: todo!(),
                            arg_value_boolean: todo!(),
                            arg_value_binary: todo!(),
                            arg_value_string: todo!(),
                            arg_value_list: todo!(),
                            position_in_args: ugen_args.next() as i16,
                            height,
                        })
                        .collect(),
                    t.payments
                        .into_iter()
                        .map(|p| Tx16Payment {
                            tx_uid: uid,
                            amount: p.amount,
                            position_in_payment: ugen_payments.next() as i16,
                            height,
                            asset_id: into_b58(p.asset_id),
                        })
                        .collect(),
                ))
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
                asset_id: into_b58(t.asset_id),
                asset_name: t.name,
                description: t.description,
            }),
            Data::InvokeExpression(t) => Tx::InvokeExpression,
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
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub amount: i64,
    pub asset_id: String,
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
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub recipient_address: String,
    pub recipient_alias: Option<String>,
    pub amount: i64,
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
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub lease_tx_uid: Option<i64>,
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
    pub sender: Sender,
    pub sender_public_key: SenderPubKey,
    pub status: Status,
    pub asset_id: String,
    pub asset_name: String,
    pub description: String,
}
