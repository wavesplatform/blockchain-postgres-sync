use crate::schema::waves_data;
use bigdecimal::BigDecimal;
use diesel::Insertable;

#[derive(Debug, Clone, Insertable)]
#[table_name = "waves_data"]
pub struct WavesData {
    height: i32,
    quantity: BigDecimal,
}
