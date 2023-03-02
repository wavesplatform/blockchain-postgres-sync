use crate::utils::into_base58;
use bytes::{BufMut, BytesMut};
use lazy_static::lazy_static;
use regex::Regex;
use std::convert::TryInto;

lazy_static! {
    pub static ref ASSET_ORACLE_DATA_ENTRY_KEY_REGEX: Regex =
        Regex::new(r"^(.*)_<([a-zA-Z\d]+)>$").unwrap();
}

pub type ChainId = u8;

pub const WAVES_ID: &str = "WAVES";

pub fn keccak256(message: &[u8]) -> [u8; 32] {
    use sha3::{Digest, Keccak256};

    let mut hasher = Keccak256::new();
    hasher.update(message);
    hasher.finalize().into()
}

pub fn blake2b256(message: &[u8]) -> [u8; 32] {
    use blake2::digest::Update;
    use blake2::digest::VariableOutput;
    use blake2::VarBlake2b;

    let mut hasher = VarBlake2b::new(32).unwrap();
    let mut arr = [0u8; 32];

    hasher.update(message);
    hasher.finalize_variable(|res| arr = res.try_into().unwrap());
    arr
}

pub struct Address(String);
pub struct PublicKeyHash<'b>(pub &'b [u8]);

impl From<(&[u8], ChainId)> for Address {
    fn from((pk, chain_id): (&[u8], ChainId)) -> Self {
        let pkh = keccak256(&blake2b256(pk));

        let mut addr = BytesMut::with_capacity(26); // VERSION + CHAIN_ID + PKH + checksum

        addr.put_u8(1); // address version is always 1
        addr.put_u8(chain_id);
        addr.put_slice(&pkh[..20]);

        let chks = &keccak256(&blake2b256(&addr[..22]))[..4];

        addr.put_slice(chks);

        Address(into_base58(addr))
    }
}

impl From<(PublicKeyHash<'_>, ChainId)> for Address {
    fn from((PublicKeyHash(hash), chain_id): (PublicKeyHash, ChainId)) -> Self {
        let mut addr = BytesMut::with_capacity(26);

        addr.put_u8(1);
        addr.put_u8(chain_id);
        addr.put_slice(hash);

        let chks = &keccak256(&blake2b256(&addr[..22]))[..4];

        addr.put_slice(chks);

        Address(into_base58(addr))
    }
}

impl From<Address> for String {
    fn from(v: Address) -> Self {
        v.0
    }
}

pub fn is_valid_base58(src: &str) -> bool {
    bs58::decode(src).into_vec().is_ok()
}

pub fn extract_asset_id(asset_id: impl AsRef<[u8]>) -> String {
    if asset_id.as_ref().is_empty() {
        WAVES_ID.to_string()
    } else {
        into_base58(asset_id)
    }
}

pub fn is_waves_asset_id(input: impl AsRef<[u8]>) -> bool {
    extract_asset_id(input) == WAVES_ID
}

#[cfg(test)]
mod tests {
    use super::is_valid_base58;

    #[test]
    fn should_validate_base58_string() {
        let test_cases = vec![
            ("3PC9BfRwJWWiw9AREE2B3eWzCks3CYtg4yo", true),
            ("not-valid-string", false),
        ];

        test_cases.into_iter().for_each(|(key, expected)| {
            let actual = is_valid_base58(&key);
            assert_eq!(actual, expected);
        });
    }
}
