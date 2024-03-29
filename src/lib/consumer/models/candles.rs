use crate::schema::candles;
use bigdecimal::BigDecimal;
use chrono::NaiveDateTime;
use diesel::Insertable;

#[derive(Debug, Insertable)]
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
    matcher_address: String,
}

pub mod intervals {
    pub const MIN1: &str = "1m";
    pub const MIN5: &str = "5m";
    pub const MIN15: &str = "15m";
    pub const MIN30: &str = "30m";
    pub const HOUR1: &str = "1h";
    pub const HOUR2: &str = "2h";
    pub const HOUR3: &str = "3h";
    pub const HOUR4: &str = "4h";
    pub const HOUR6: &str = "6h";
    pub const HOUR12: &str = "12h";
    pub const DAY1: &str = "1d";
    pub const WEEK1: &str = "1w";
    pub const MONTH1: &str = "1M";

    pub const CANDLE_INTERVALS: &[[&str; 2]] = &[
        [MIN1, MIN5],
        [MIN5, MIN15],
        [MIN15, MIN30],
        [MIN30, HOUR1],
        [HOUR1, HOUR2],
        [HOUR1, HOUR3],
        [HOUR2, HOUR4],
        [HOUR3, HOUR6],
        [HOUR6, HOUR12],
        [HOUR12, DAY1],
        [DAY1, WEEK1],
        [DAY1, MONTH1],
    ];
}

pub fn interval_in_seconds(interval: &str) -> Option<i64> {
    match interval {
        intervals::MIN1 => Some(60),
        intervals::MIN5 => Some(60 * 5),
        intervals::MIN15 => Some(60 * 15),
        intervals::MIN30 => Some(60 * 30),
        intervals::HOUR1 => Some(60 * 60),
        intervals::HOUR2 => Some(60 * 60 * 2),
        intervals::HOUR3 => Some(60 * 60 * 3),
        intervals::HOUR4 => Some(60 * 60 * 4),
        intervals::HOUR6 => Some(60 * 60 * 6),
        intervals::HOUR12 => Some(60 * 60 * 12),
        intervals::DAY1 => Some(60 * 60 * 24),
        _ => None,
    }
}
