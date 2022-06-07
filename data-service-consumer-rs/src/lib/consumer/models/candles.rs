use crate::schema::*;
use bigdecimal::BigDecimal;
use chrono::NaiveDateTime;
use diesel::Insertable;

#[derive(Debug, Clone, Insertable)]
pub struct Candle {
    time_start: NaiveDateTime,
    amount_asset_id: String,
    price_asset_id: String,
    low: BigDecimal,
    high: BigDecimal,
    volume: BigDecimal,
    quote_volume: BigDecimal,
    max_height: i32,
    txs_count: i32,
    weighted_average_price: BigDecimal,
    open: BigDecimal,
    close: BigDecimal,
    interval: String,
    matcher: String,
}
