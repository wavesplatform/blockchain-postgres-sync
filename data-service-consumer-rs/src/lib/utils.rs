use chrono::NaiveDateTime;

pub fn into_b58(b: impl AsRef<[u8]>) -> String {
    bs58::encode(b.as_ref()).into_string()
}

pub fn into_prefixed_b64(b: impl AsRef<[u8]>) -> String {
    let b = b.as_ref();
    if b.len() > 0 {
        String::from("base64:") + &base64::encode(b)
    } else {
        String::new()
    }
}

pub fn epoch_ms_to_naivedatetime(ts: i64) -> NaiveDateTime {
    NaiveDateTime::from_timestamp(ts / 1000, (ts % 1000) as u32 * 1_000_000)
}

pub fn escape_unicode_null(s: &str) -> String {
    s.replace("\0", "\\0")
}
