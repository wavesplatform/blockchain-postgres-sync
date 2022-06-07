use crate::schema::tickers;
use diesel::Insertable;

#[derive(Debug, Clone, Insertable)]
pub struct Ticker {
    pub asset_id: String,
    pub ticker: String,
}
