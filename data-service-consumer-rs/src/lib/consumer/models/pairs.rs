use crate::schema::pairs;
use bigdecimal::BigDecimal;
use diesel::Insertable;

#[derive(Debug, Clone, Insertable)]
pub struct Pair {
    amount_asset_id: String,
    price_asset_id: String,
    first_price: BigDecimal,
    last_price: BigDecimal,
    volume: BigDecimal,
    volume_waves: Option<BigDecimal>,
    quote_volume: BigDecimal,
    high: BigDecimal,
    low: BigDecimal,
    weighted_average_price: BigDecimal,
    txs_count: i32,
    matcher_address: String,
}
