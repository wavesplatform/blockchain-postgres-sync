use bytes::{BufMut, BytesMut};
use lazy_static::lazy_static;
use regex::Regex;
use std::convert::TryInto;

lazy_static! {
    pub static ref ASSET_ORACLE_DATA_ENTRY_KEY_REGEX: Regex =
        Regex::new(r"^(.*)_<([a-zA-Z\d]+)>$").unwrap();
}

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

    hasher.update(message);

    let mut arr = [0u8; 32];

    hasher.finalize_variable(|res| arr = res.try_into().unwrap());

    arr
}

pub struct Address(String);
pub struct RawPublicKey(Vec<u8>);
pub struct RawAddress(Vec<u8>);

impl From<(RawPublicKey, u8)> for Address {
    fn from(data: (RawPublicKey, u8)) -> Self {
        let (RawPublicKey(pk), chain_id) = data;

        let pkh = keccak256(&blake2b256(&pk));

        let mut addr = BytesMut::with_capacity(26); // VERSION + CHAIN_ID + PKH + checksum

        addr.put_u8(1); // address version is always 1
        addr.put_u8(chain_id);
        addr.put_slice(&pkh[..20]);

        let chks = &keccak256(&blake2b256(&addr[..22]))[..4];

        addr.put_slice(chks);

        Address(bs58::encode(addr).into_string())
    }
}

impl From<(&[u8], u8)> for Address {
    fn from(data: (&[u8], u8)) -> Self {
        let (pk, chain_id) = data;

        let pkh = keccak256(&blake2b256(pk));

        let mut addr = BytesMut::with_capacity(26); // VERSION + CHAIN_ID + PKH + checksum

        addr.put_u8(1); // address version is always 1
        addr.put_u8(chain_id);
        addr.put_slice(&pkh[..20]);

        let chks = &keccak256(&blake2b256(&addr[..22]))[..4];

        addr.put_slice(chks);

        Address(bs58::encode(addr).into_string())
    }
}

impl From<(RawAddress, u8)> for Address {
    fn from(data: (RawAddress, u8)) -> Self {
        let (RawAddress(address), chain_id) = data;

        let mut addr = BytesMut::with_capacity(26);

        addr.put_u8(1);
        addr.put_u8(chain_id);
        addr.put_slice(&address[..]);

        let chks = &keccak256(&blake2b256(&addr[..22]))[..4];

        addr.put_slice(chks);

        Address(bs58::encode(addr).into_string())
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

pub const WAVES_ID: &str = "WAVES";
pub const WAVES_NAME: &str = "Waves";
pub const WAVES_PRECISION: i32 = 8;

pub fn get_asset_id<I: AsRef<[u8]>>(input: I) -> String {
    if input.as_ref().is_empty() {
        WAVES_ID.to_owned()
    } else {
        bs58::encode(input).into_string()
    }
}

pub fn is_waves_asset_id<I: AsRef<[u8]>>(input: I) -> bool {
    get_asset_id(input) == WAVES_ID
}

#[derive(Clone, Debug, PartialEq)]
pub struct WavesAssociationKey {
    source: String,
    pub asset_id: String,
    pub key_without_asset_id: String,
}

pub const KNOWN_WAVES_ASSOCIATION_ASSET_ATTRIBUTES: &'static [&str] = &[
    "description",
    "link",
    "logo",
    "status",
    "ticker",
    "email",
    "version",
];

/// Parses data entry key written in Waves Assiciation format
/// respectively to the allowed attributes vector
///
/// This format described as `{attribute}_<{asset_id}>`
///
/// Example: `description_<en>_<9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y>` will be parsed into:
/// - `attribute = description_<en>`
/// - `asset_id = 9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y`
pub fn parse_waves_association_key(
    allowed_attributes: &[&str],
    key: &str,
) -> Option<WavesAssociationKey> {
    ASSET_ORACLE_DATA_ENTRY_KEY_REGEX
        .captures(key)
        .and_then(|cs| {
            if cs.len() >= 2 {
                let key_without_asset_id = cs.get(1).map(|k| k.as_str());
                match allowed_attributes
                    .iter()
                    .find(|allowed_attribute| match key_without_asset_id {
                        Some(key) => key.starts_with(*allowed_attribute),
                        _ => false,
                    }) {
                    Some(_allowed_attribute) => {
                        let asset_id = cs.get(cs.len() - 1).map(|k| k.as_str());
                        key_without_asset_id.zip(asset_id).map(
                            |(key_without_asset_id, asset_id)| WavesAssociationKey {
                                source: key.to_owned(),
                                key_without_asset_id: key_without_asset_id.to_owned(),
                                asset_id: asset_id.to_owned(),
                            },
                        )
                    }
                    _ => None,
                }
            } else {
                None
            }
        })
}

#[cfg(test)]
mod tests {
    use super::{
        is_valid_base58, parse_waves_association_key, WavesAssociationKey,
        KNOWN_WAVES_ASSOCIATION_ASSET_ATTRIBUTES,
    };

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

    #[test]
    fn should_parse_waves_association_key() {
        let test_cases = vec![
            (
                "link_<9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y>",
                Some(WavesAssociationKey {
                    source: "link_<9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y>".to_owned(),
                    key_without_asset_id: "link".to_owned(),
                    asset_id: "9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y".to_owned(),
                }),
            ),
            (
                "description_<en>_<9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y>",
                Some(WavesAssociationKey {
                    source: "description_<en>_<9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y>"
                        .to_owned(),
                    key_without_asset_id: "description_<en>".to_owned(),
                    asset_id: "9sQutD5HnRvjM1uui5cVC4w9xkMPAfYEV8ymug3Mon2Y".to_owned(),
                }),
            ),
            ("data_provider_description_<en>", None),
            ("test", None),
        ];

        test_cases.into_iter().for_each(|(key, expected)| {
            let actual =
                parse_waves_association_key(&KNOWN_WAVES_ASSOCIATION_ASSET_ATTRIBUTES, key);
            assert_eq!(actual, expected);
        });
    }
}
