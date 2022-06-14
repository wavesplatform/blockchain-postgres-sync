use crate::error::Error;
use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;
use serde_json::Value;
use waves_protobuf_schemas::waves::{
    recipient::Recipient as InnerRecipient, signed_transaction::Transaction, transaction::Data,
    Recipient, SignedTransaction,
};

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
    MassTransfer(Tx11),
    DataTransaction(Tx12),
    SetScript(Tx13),
    SponsorFee(Tx14),
    SetAssetScript(Tx15),
    InvokeScript(Tx16),
    UpdateAssetInfo(Tx17),
    InvokeExpression,
}

impl TryFrom<(SignedTransaction, Id, Height, Vec<u8>)> for Tx {
    type Error = Error;

    fn try_from(
        (tx, id, height, sender): (SignedTransaction, Id, Height, Vec<u8>),
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
            Transaction::EthereumTransaction(_) => todo!(),
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

        let parse_attachment = |a| String::from_utf8(a).unwrap_or_else(|_| into_b58(a));
        let parse_recipient = |r: Recipient| match r.recipient.unwrap() {
            InnerRecipient::Alias(a) => a,
            InnerRecipient::PublicKeyHash(p) => into_b58(p),
        };

        Ok(match tx_data {
            Data::Genesis(t) => Tx::Genesis(Tx1 {
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
                recipient: into_b58(t.recipient_address),
                amount: t.amount,
            }),
            Data::Payment(t) => Tx::Payment(Tx2 {
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
                recipient: into_b58(t.recipient_address),
                amount: t.amount,
            }),
            Data::Issue(t) => Tx::Issue(Tx3 {
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
                asset_id: todo!(),
                // TODO: is really unwrap
                fee_asset: into_b58(tx.fee.unwrap().asset_id),
                attachment: parse_attachment(t.attachment),
            }),
            Data::Reissue(t) => Tx::Reissue(Tx5 {
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
                order1: todo!(),
                order2: todo!(),
                amount_asset: todo!(),
                price_asset: todo!(),
                amount: todo!(),
                price: todo!(),
                buy_matcher_fee: todo!(),
                sell_matcher_fee: todo!(),
            }),
            Data::Lease(t) => Tx::Lease(Tx8 {
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
                recipient: parse_recipient(t.recipient.unwrap()),
                amount: t.amount,
            }),
            Data::LeaseCancel(t) => Tx::LeaseCancel(Tx9 {
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
                //TODO
                lease_tx_uid: if t.lease_id.len() > 0 {
                    Some(i64::from_be_bytes(&t.lease_id))
                } else {
                    None
                },
            }),
            Data::CreateAlias(t) => Tx::CreateAlias(Tx10 {
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
            Data::MassTransfer(t) => Tx::MassTransfer(Tx11 {
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
            }),
            Data::DataTransaction(t) => Tx::DataTransaction(Tx12 {
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
            }),
            Data::SetScript(t) => Tx::SetScript(Tx13 {
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
            Data::InvokeScript(t) => Tx::InvokeScript(Tx16 {
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
                dapp: todo!(),
                function_name: todo!(),
                fee_asset_id: todo!(),
            }),
            Data::UpdateAssetInfo(t) => Tx::UpdateAssetInfo(Tx17 {
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
    pub lease_tx_uid: Option<i64>,
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
