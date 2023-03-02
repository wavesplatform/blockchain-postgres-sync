use super::*;
use crate::error::Error;
use crate::models::{DataEntryTypeValue, Order, OrderMeta};
use crate::utils::{
    epoch_ms_to_naivedatetime, escape_unicode_null, into_base58, into_prefixed_base64,
};
use crate::waves::{extract_asset_id, Address, ChainId, PublicKeyHash, WAVES_ID};
use serde_json::json;
use waves_protobuf_schemas::waves::{
    data_transaction_data::data_entry::Value as DataValue,
    events::{
        transaction_metadata::{ethereum_metadata::Action as EthAction, *},
        TransactionMetadata,
    },
    invoke_script_result::call::argument::Value as InvokeScriptArgValue,
    recipient::Recipient as InnerRecipient,
    signed_transaction::Transaction,
    transaction::Data,
    Amount, Recipient, SignedTransaction,
};

const WRONG_META_VAR: &str = "wrong meta variant";

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
    Ethereum(Tx18Combined),
}

pub struct TxUidGenerator {
    multiplier: i64,
    last_height: TxHeight,
    last_id: TxUid,
}

impl TxUidGenerator {
    pub const fn new(multiplier: i64) -> Self {
        Self {
            multiplier,
            last_height: 0,
            last_id: 0,
        }
    }

    pub fn maybe_update_height(&mut self, height: TxHeight) {
        if self.last_height < height {
            self.last_height = height;
            self.last_id = 0;
        }
    }

    pub fn next(&mut self) -> TxUid {
        let result = self.last_height as i64 * self.multiplier + self.last_id;
        self.last_id += 1;
        result
    }
}

impl
    TryFrom<(
        &SignedTransaction,
        &TxId,
        TxHeight,
        &TransactionMetadata,
        TxUid,
        TxBlockUid,
        ChainId,
    )> for Tx
{
    type Error = Error;

    fn try_from(
        (tx, id, height, meta, tx_uid, block_uid, chain_id): (
            &SignedTransaction,
            &TxId,
            TxHeight,
            &TransactionMetadata,
            TxUid,
            TxBlockUid,
            ChainId,
        ),
    ) -> Result<Self, Self::Error> {
        let SignedTransaction {
            transaction: Some(tx),
            proofs,
        } = tx else {
            return Err(Error::InconsistDataError(format!(
                "No transaction data in id={id}, height={height}",
            )))
        };
        let uid = tx_uid;
        let id = id.to_owned();
        let proofs = proofs.iter().map(into_base58).collect::<Vec<_>>();
        let signature = proofs
            .get(0)
            .and_then(|p| (p.len() > 0).then_some(p.to_owned()));
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
                if let Some(_) = result.error_message {
                    status = String::from("script_execution_failed");
                }
            }
        }

        let sender = into_base58(&meta.sender_address);

        let tx = match tx {
            Transaction::WavesTransaction(tx) => tx,
            Transaction::EthereumTransaction(tx) => {
                let Some(Metadata::Ethereum(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
                };
                let mut eth_tx = Tx18 {
                    uid,
                    height,
                    tx_type: 18,
                    id,
                    time_stamp: epoch_ms_to_naivedatetime(meta.timestamp),
                    signature,
                    fee: meta.fee,
                    proofs,
                    tx_version: Some(1),
                    sender,
                    sender_public_key: into_base58(&meta.sender_public_key),
                    status,
                    payload: tx.clone(),
                    block_uid,
                    function_name: None,
                };
                let result_tx = match meta.action.as_ref().unwrap() {
                    EthAction::Transfer(_) => Tx18Combined {
                        tx: eth_tx,
                        args: vec![],
                        payments: vec![],
                    },
                    EthAction::Invoke(imeta) => {
                        eth_tx.function_name = Some(imeta.function_name.clone());
                        Tx18Combined {
                            tx: eth_tx,
                            args: imeta
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
                                            Some(
                                                json!(DataEntryTypeValue::from(arg))["value"]
                                                    .clone(),
                                            ),
                                        ),
                                        InvokeScriptArgValue::CaseObj(_) => {
                                            ("case", None, None, None, None, None)
                                        }
                                    };
                                    Tx18Args {
                                        tx_uid,
                                        arg_type: v_type.to_string(),
                                        arg_value_integer: v_int,
                                        arg_value_boolean: v_bool,
                                        arg_value_binary: v_bin.map(into_prefixed_base64),
                                        arg_value_string: v_str.map(escape_unicode_null),
                                        arg_value_list: v_list,
                                        position_in_args: i as i16,
                                        height,
                                    }
                                })
                                .collect(),
                            payments: imeta
                                .payments
                                .iter()
                                .enumerate()
                                .map(|(i, p)| Tx18Payment {
                                    tx_uid,
                                    amount: p.amount,
                                    position_in_payment: i as i16,
                                    height,
                                    asset_id: extract_asset_id(&p.asset_id),
                                })
                                .collect(),
                        }
                    }
                };
                return Ok(Tx::Ethereum(result_tx));
            }
        };
        let tx_data = tx.data.as_ref().ok_or_else(|| {
            Error::InconsistDataError(format!(
                "No inner transaction data in id={id}, height={height}",
            ))
        })?;
        let time_stamp = epoch_ms_to_naivedatetime(tx.timestamp);
        let (fee, fee_asset_id) = tx
            .fee
            .as_ref()
            .map(|f| (f.amount, extract_asset_id(&f.asset_id)))
            .unwrap_or((0, WAVES_ID.to_string()));
        let tx_version = Some(tx.version as i16);
        let sender_public_key = into_base58(&tx.sender_public_key);

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
                tx_version: None,
                sender: (sender.len() > 0).then_some(sender),
                sender_public_key: (sender_public_key.len() > 0).then_some(sender_public_key),
                status,
                recipient_address: Address::from((
                    PublicKeyHash(t.recipient_address.as_ref()),
                    chain_id,
                ))
                .into(),
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
                tx_version: tx_version.and_then(|v| (v != 1).then_some(v)),
                sender,
                sender_public_key,
                status,
                recipient_address: Address::from((
                    PublicKeyHash(t.recipient_address.as_ref()),
                    chain_id,
                ))
                .into(),
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
                asset_id: if id.is_empty() {
                    WAVES_ID.to_string()
                } else {
                    id
                },
                asset_name: escape_unicode_null(&t.name),
                description: escape_unicode_null(&t.description),
                quantity: t.amount,
                decimals: t.decimals as i16,
                reissuable: t.reissuable,
                script: extract_script(&t.script),
                block_uid,
            }),
            Data::Transfer(t) => {
                let Some(Metadata::Transfer(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
                };
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
                    asset_id: extract_asset_id(asset_id),
                    fee_asset_id,
                    amount: *amount,
                    attachment: into_base58(&t.attachment),
                    recipient_address: into_base58(&meta.recipient_address),
                    recipient_alias: extract_recipient_alias(&t.recipient),
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
                    asset_id: extract_asset_id(asset_id),
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
                    asset_id: extract_asset_id(asset_id),
                    amount: *amount,
                    block_uid,
                })
            }
            Data::Exchange(t) => {
                let order_to_val = |o| serde_json::to_value(Order::from(o)).unwrap();
                let Some(Metadata::Exchange(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
                };
                let order_1 = OrderMeta {
                    order: &t.orders[0],
                    id: &meta.order_ids[0],
                    sender_address: &meta.order_sender_addresses[0],
                    sender_public_key: &meta.order_sender_public_keys[0],
                };
                let order_2 = OrderMeta {
                    order: &t.orders[1],
                    id: &meta.order_ids[1],
                    sender_address: &meta.order_sender_addresses[1],
                    sender_public_key: &meta.order_sender_public_keys[1],
                };
                let first_order_asset_pair = t.orders[0].asset_pair.as_ref().unwrap();
                Tx::Exchange(Tx7 {
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
                    order1: order_to_val(order_1),
                    order2: order_to_val(order_2),
                    amount_asset_id: extract_asset_id(&first_order_asset_pair.amount_asset_id),
                    price_asset_id: extract_asset_id(&first_order_asset_pair.price_asset_id),
                    amount: t.amount,
                    price: t.price,
                    buy_matcher_fee: t.buy_matcher_fee,
                    sell_matcher_fee: t.sell_matcher_fee,
                    fee_asset_id,
                    block_uid,
                })
            }
            Data::Lease(t) => {
                let Some(Metadata::Lease(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
                };
                Tx::Lease(Tx8 {
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
                    recipient_address: into_base58(&meta.recipient_address),
                    recipient_alias: extract_recipient_alias(&t.recipient),
                    block_uid,
                })
            }
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
                    Some(into_base58(&t.lease_id))
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
            Data::MassTransfer(t) => {
                let Some(Metadata::MassTransfer(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
                };
                Tx::MassTransfer(Tx11Combined {
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
                        asset_id: extract_asset_id(&t.asset_id),
                        attachment: into_base58(&t.attachment),
                        block_uid,
                    },
                    transfers: t
                        .transfers
                        .iter()
                        .zip(&meta.recipients_addresses)
                        .enumerate()
                        .map(|(i, (t, rcpt_addr))| Tx11Transfers {
                            tx_uid,
                            recipient_address: into_base58(rcpt_addr),
                            recipient_alias: extract_recipient_alias(&t.recipient),
                            amount: t.amount,
                            position_in_tx: i as i16,
                            height,
                        })
                        .collect(),
                })
            }
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
                            tx_uid,
                            data_key: escape_unicode_null(&d.key),
                            data_type: v_type.map(String::from),
                            data_value_integer: v_int,
                            data_value_boolean: v_bool,
                            data_value_binary: v_bin.map(into_prefixed_base64),
                            data_value_string: v_str.map(escape_unicode_null),
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
                script: extract_script(&t.script),
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
                asset_id: extract_asset_id(&t.min_fee.as_ref().unwrap().asset_id),
                min_sponsored_asset_fee: t
                    .min_fee
                    .as_ref()
                    .and_then(|f| (f.amount != 0).then_some(f.amount)),
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
                asset_id: extract_asset_id(&t.asset_id),
                script: extract_script(&t.script),
                block_uid,
            }),
            Data::InvokeScript(t) => {
                let Some(Metadata::InvokeScript(meta)) = &meta.metadata else {
                    unreachable!("{WRONG_META_VAR}")
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
                        fee_asset_id: extract_asset_id(&tx.fee.as_ref().unwrap().asset_id),
                        dapp_address: into_base58(&meta.d_app_address),
                        dapp_alias: extract_recipient_alias(&t.d_app),
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
                                tx_uid,
                                arg_type: v_type.to_string(),
                                arg_value_integer: v_int,
                                arg_value_boolean: v_bool,
                                arg_value_binary: v_bin.map(into_prefixed_base64),
                                arg_value_string: v_str.map(escape_unicode_null),
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
                            tx_uid,
                            amount: p.amount,
                            position_in_payment: i as i16,
                            height,
                            asset_id: extract_asset_id(&p.asset_id),
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
                asset_id: extract_asset_id(&t.asset_id),
                asset_name: escape_unicode_null(&t.name),
                description: escape_unicode_null(&t.description),
                block_uid,
            }),
            Data::InvokeExpression(_t) => unimplemented!(),
        })
    }
}

fn extract_recipient_alias(rcpt: &Option<Recipient>) -> Option<String> {
    rcpt.as_ref()
        .map(|r| r.recipient.as_ref())
        .flatten()
        .and_then(|r| match r {
            InnerRecipient::Alias(alias) if !alias.is_empty() => Some(alias.clone()),
            _ => None,
        })
}

fn extract_script(script: &Vec<u8>) -> Option<String> {
    if !script.is_empty() {
        Some(into_prefixed_base64(script))
    } else {
        None
    }
}
