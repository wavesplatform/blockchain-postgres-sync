use crate::consumer::BlockMicroblockAppend;
use crate::schema::*;
use chrono::NaiveDateTime;
use diesel::Insertable;

#[derive(Clone, Debug, Insertable, QueryableByName)]
#[diesel(table_name = blocks_microblocks)]
pub struct BlockMicroblock {
    pub id: String,
    pub time_stamp: Option<NaiveDateTime>,
    pub height: i32,
}

impl From<BlockMicroblockAppend> for BlockMicroblock {
    fn from(bma: BlockMicroblockAppend) -> Self {
        Self {
            id: bma.id,
            time_stamp: bma.time_stamp,
            height: bma.height,
        }
    }
}
