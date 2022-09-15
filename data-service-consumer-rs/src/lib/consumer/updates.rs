use anyhow::Result;
use async_trait::async_trait;
use bs58;
use chrono::Duration;
use std::str;
use std::time::{Duration as StdDuration, Instant};
use tokio::sync::mpsc::{channel, Receiver, Sender};
use tokio::time;
use waves_protobuf_schemas::waves::{
    block::Header as HeaderPB,
    events::{
        blockchain_updated::append::{
            BlockAppend as BlockAppendPB, Body as BodyPB, MicroBlockAppend as MicroBlockAppendPB,
        },
        blockchain_updated::Append as AppendPB,
        blockchain_updated::Update as UpdatePB,
        grpc::{
            blockchain_updates_api_client::BlockchainUpdatesApiClient,
            SubscribeEvent as SubscribeEventPB, SubscribeRequest as SubscribeRequestPB,
        },
        BlockchainUpdated as BlockchainUpdatedPB,
    },
    Block as BlockPB, SignedMicroBlock as SignedMicroBlockPB,
    SignedTransaction as SignedTransactionPB,
};
use wavesexchange_log::{debug, error};

use super::{
    epoch_ms_to_naivedatetime, BlockMicroblockAppend, BlockchainUpdate,
    BlockchainUpdatesWithLastHeight, Tx, UpdatesSource,
};
use crate::error::Error as AppError;

#[derive(Clone)]
pub struct UpdatesSourceImpl {
    grpc_client: BlockchainUpdatesApiClient<tonic::transport::Channel>,
}

pub async fn new(blockchain_updates_url: &str) -> Result<UpdatesSourceImpl> {
    Ok(UpdatesSourceImpl {
        grpc_client: BlockchainUpdatesApiClient::connect(blockchain_updates_url.to_owned()).await?,
    })
}

#[async_trait]
impl UpdatesSource for UpdatesSourceImpl {
    async fn stream(
        self,
        from_height: u32,
        batch_max_size: usize,
        batch_max_wait_time: Duration,
    ) -> Result<Receiver<BlockchainUpdatesWithLastHeight>, AppError> {
        let request = tonic::Request::new(SubscribeRequestPB {
            from_height: from_height as i32,
            to_height: 0,
        });

        let stream: tonic::Streaming<SubscribeEventPB> = self
            .grpc_client
            .clone()
            .subscribe(request)
            .await
            .map_err(|e| AppError::StreamError(format!("Subscribe Stream error: {}", e)))?
            .into_inner();

        let (tx, rx) = channel::<BlockchainUpdatesWithLastHeight>(1);

        tokio::spawn(async move {
            let r = self
                .run(stream, tx, from_height, batch_max_size, batch_max_wait_time)
                .await;
            if let Err(e) = r {
                error!("updates source stopped with error: {:?}", e);
            } else {
                error!("updates source stopped without an error")
            }
        });

        Ok(rx)
    }
}

impl UpdatesSourceImpl {
    async fn run(
        &self,
        mut stream: tonic::Streaming<SubscribeEventPB>,
        tx: Sender<BlockchainUpdatesWithLastHeight>,
        from_height: u32,
        batch_max_size: usize,
        batch_max_wait_time: Duration,
    ) -> Result<(), AppError> {
        let mut result = vec![];
        let mut last_height = from_height;

        let mut start = Instant::now();
        let mut should_receive_more = true;

        let batch_max_wait_time = batch_max_wait_time.to_std().unwrap();

        loop {
            if let Some(SubscribeEventPB {
                update: Some(update),
            }) = stream
                .message()
                .await
                .map_err(|s| AppError::StreamError(format!("Updates stream error: {}", s)))?
            {
                last_height = update.height as u32;
                match BlockchainUpdate::try_from(update) {
                    Ok(upd) => {
                        let current_batch_size = result.len() + 1;
                        match &upd {
                            BlockchainUpdate::Block(_) => {
                                if current_batch_size >= batch_max_size
                                    || start.elapsed().ge(&batch_max_wait_time)
                                {
                                    should_receive_more = false;
                                }
                            }
                            BlockchainUpdate::Microblock(_) | BlockchainUpdate::Rollback(_) => {
                                should_receive_more = false
                            }
                        }
                        result.push(upd);
                        Ok(())
                    }
                    Err(err) => Err(err),
                }?;
            }

            if !should_receive_more {
                debug!("updating to height {}", last_height);
                tx.send(BlockchainUpdatesWithLastHeight {
                    last_height,
                    updates: result.drain(..).collect(),
                })
                .await
                .map_err(|e| AppError::StreamError(format!("Channel error: {}", e)))?;
                should_receive_more = true;
                start = Instant::now();
            }

            time::sleep(StdDuration::from_micros(1000)).await;
        }
    }
}

impl TryFrom<BlockchainUpdatedPB> for BlockchainUpdate {
    type Error = AppError;

    fn try_from(mut value: BlockchainUpdatedPB) -> Result<Self, Self::Error> {
        use BlockchainUpdate::{Block, Microblock, Rollback};

        match value.update {
            Some(UpdatePB::Append(AppendPB {
                ref mut body,
                state_update: Some(_),
                transaction_ids,
                transactions_metadata,
                transaction_state_updates,
                ..
            })) => {
                let height = value.height;

                let txs: Option<(Vec<SignedTransactionPB>, Option<i64>)> = match body {
                    Some(BodyPB::Block(BlockAppendPB { ref mut block, .. })) => {
                        Ok(block.as_mut().map(|it| {
                            (
                                it.transactions.drain(..).collect(),
                                it.header.as_ref().map(|it| it.timestamp),
                            )
                        }))
                    }
                    Some(BodyPB::MicroBlock(MicroBlockAppendPB {
                        ref mut micro_block,
                        ..
                    })) => Ok(micro_block.as_mut().and_then(|it| {
                        it.micro_block
                            .as_mut()
                            .map(|it| (it.transactions.drain(..).collect(), None))
                    })),
                    _ => Err(AppError::InvalidMessage(
                        "Append body is empty.".to_string(),
                    )),
                }?;

                let txs = match txs {
                    Some((txs, ..)) => txs
                        .into_iter()
                        .enumerate()
                        .map(|(idx, tx)| {
                            let id = transaction_ids.get(idx).unwrap().clone();
                            Tx {
                                id: bs58::encode(id).into_string(),
                                data: tx,
                                meta: transactions_metadata.get(idx).unwrap().clone(),
                                state_update: transaction_state_updates.get(idx).unwrap().clone(),
                            }
                        })
                        .collect(),
                    None => vec![],
                };

                match body {
                    Some(BodyPB::Block(BlockAppendPB {
                        block:
                            Some(BlockPB {
                                header: Some(HeaderPB { timestamp, .. }),
                                ..
                            }),
                        updated_waves_amount,
                    })) => Ok(Block(BlockMicroblockAppend {
                        id: bs58::encode(&value.id).into_string(),
                        time_stamp: Some(epoch_ms_to_naivedatetime(*timestamp)),
                        height,
                        updated_waves_amount: if *updated_waves_amount > 0 {
                            Some(*updated_waves_amount)
                        } else {
                            None
                        },
                        txs,
                    })),
                    Some(BodyPB::MicroBlock(MicroBlockAppendPB {
                        micro_block: Some(SignedMicroBlockPB { total_block_id, .. }),
                        ..
                    })) => Ok(Microblock(BlockMicroblockAppend {
                        id: bs58::encode(&total_block_id).into_string(),
                        time_stamp: None,
                        height,
                        updated_waves_amount: None,
                        txs,
                    })),
                    _ => Err(AppError::InvalidMessage(
                        "Append body is empty.".to_string(),
                    )),
                }
            }
            Some(UpdatePB::Rollback(_)) => Ok(Rollback(bs58::encode(&value.id).into_string())),
            _ => Err(AppError::InvalidMessage(
                "Unknown blockchain update.".to_string(),
            )),
        }
    }
}
