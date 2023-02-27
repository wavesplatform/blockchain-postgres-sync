use crate::schema::waves_data;
use bigdecimal::BigDecimal;
use diesel::Insertable;

#[derive(Debug, Clone, Insertable)]
#[table_name = "waves_data"]
pub struct WavesData {
    pub height: i32,
    pub quantity: BigDecimal,
}
