// https://github.com/wavesplatform/docs.wavesplatform/blob/master/docs/ru/blockchain/binary-format/transaction-binary-format/invoke-script-transaction-binary-format.md
use crate::models::DataEntryTypeValue;
use nom::branch::alt;
use nom::bytes::complete::{tag, take};
use nom::error::context;
use nom::multi::count;
use nom::number::complete::{be_i64, be_u32, be_u8};
use nom::sequence::tuple;
use nom::IResult;

#[derive(Debug)]
pub struct FunctionCall {
    pub name: String,
    pub args: Vec<DataEntryTypeValue>,
}

impl FunctionCall {
    pub fn from_raw_bytes(bytes: &[u8]) -> Result<Self, String> {
        Self::parse(bytes).map(|f| f.1).map_err(|e| e.to_string())
    }

    fn parse(input: &[u8]) -> IResult<&[u8], Self> {
        fn parse_arg(ii: &[u8]) -> IResult<&[u8], DataEntryTypeValue> {
            let (ii, arg_type) = context(
                "arg type",
                alt((
                    tag(b"\x00"), // i64
                    tag(b"\x01"), // [u8]
                    tag(b"\x02"), // str
                    tag(b"\x06"), // true
                    tag(b"\x07"), // false
                    tag(b"\x0b"), // [...]
                )),
            )(ii)?;
            let arg_type = arg_type[0];

            Ok(match arg_type {
                0 => {
                    let (ii, int) = be_i64(ii)?;
                    (ii, DataEntryTypeValue::IntVal(int))
                }
                1 => {
                    let (ii, arg_len) = be_u32(ii)?;
                    let (ii, bytes) = take(arg_len)(ii)?;

                    (
                        ii,
                        DataEntryTypeValue::BinVal(format!("base64:{}", base64::encode(bytes))),
                    )
                }
                2 => {
                    let (ii, arg_len) = be_u32(ii)?;
                    let (ii, str) = take(arg_len)(ii)?;

                    (
                        ii,
                        DataEntryTypeValue::StrVal(String::from_utf8(str.to_owned()).unwrap()),
                    )
                }
                6 => (ii, DataEntryTypeValue::BoolVal(true)),
                7 => (ii, DataEntryTypeValue::BoolVal(false)),
                11 => unimplemented!(),
                _ => unreachable!(),
            })
        }

        let (i, (_, _, _, fn_name_len)) =
            tuple((be_u8, tag(b"\x09"), tag(b"\x01"), be_u32))(input)?;
        let (i, fn_name) = take(fn_name_len)(i)?;
        let (i, argc) = be_u32(i)?;

        let (i, args) = count(parse_arg, argc as usize)(i)?;

        Ok((
            i,
            FunctionCall {
                name: String::from_utf8(fn_name.to_owned()).unwrap(),
                args,
            },
        ))
    }
}

#[derive(Debug)]
pub enum Dapp {
    Address(Vec<u8>),
    Alias(Vec<u8>),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse() {
        let raw = [
            1, 9, 1, 0, 0, 0, 20, 102, 105, 110, 97, 108, 105, 122, 101, 67, 117, 114, 114, 101,
            110, 116, 80, 114, 105, 99, 101, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 57, 251, 192, 1, 0, 0,
            0, 64, 192, 20, 166, 214, 231, 36, 186, 77, 93, 121, 118, 144, 235, 49, 224, 138, 218,
            92, 126, 205, 36, 135, 156, 162, 234, 108, 143, 39, 31, 166, 16, 197, 194, 24, 56, 237,
            189, 178, 63, 79, 190, 233, 133, 128, 215, 36, 181, 83, 156, 121, 39, 65, 187, 99, 119,
            210, 56, 140, 61, 237, 53, 115, 139, 4, 0, 0, 0, 0, 0, 0, 57, 251, 192, 1, 0, 0, 0, 64,
            176, 95, 123, 159, 70, 125, 221, 243, 203, 47, 239, 127, 247, 163, 213, 3, 183, 226,
            123, 127, 136, 211, 17, 193, 143, 202, 99, 164, 132, 248, 230, 59, 113, 167, 30, 73,
            49, 102, 35, 167, 79, 134, 118, 29, 75, 104, 72, 167, 89, 56, 183, 116, 159, 204, 143,
            48, 242, 52, 108, 84, 191, 201, 28, 1, 0, 0, 0, 0, 0, 0, 57, 251, 192, 1, 0, 0, 0, 64,
            57, 204, 15, 37, 179, 210, 188, 201, 109, 6, 203, 251, 163, 17, 59, 75, 184, 31, 181,
            245, 160, 232, 134, 108, 36, 158, 249, 30, 44, 30, 166, 85, 204, 19, 135, 153, 33, 173,
            110, 109, 49, 160, 104, 143, 91, 45, 6, 235, 9, 100, 130, 227, 158, 23, 35, 15, 112,
            160, 160, 117, 108, 158, 226, 2, 0, 0, 0, 0, 0, 0, 57, 251, 192, 1, 0, 0, 0, 64, 89,
            30, 225, 143, 109, 36, 119, 51, 194, 86, 153, 109, 143, 235, 253, 42, 230, 245, 89,
            239, 249, 200, 40, 26, 122, 62, 62, 197, 116, 80, 161, 168, 148, 85, 54, 191, 81, 50,
            143, 70, 104, 23, 12, 88, 95, 3, 155, 28, 173, 191, 4, 98, 106, 27, 169, 44, 138, 102,
            232, 48, 11, 86, 79, 4, 0, 0, 0, 0, 0, 0, 57, 251, 192, 1, 0, 0, 0, 64, 101, 119, 152,
            204, 91, 239, 162, 122, 199, 126, 117, 226, 150, 0, 28, 86, 112, 115, 73, 111, 19, 133,
            173, 203, 247, 143, 19, 217, 36, 195, 20, 213, 166, 179, 225, 76, 13, 230, 77, 97, 215,
            130, 85, 72, 138, 17, 160, 22, 85, 48, 51, 98, 16, 251, 228, 12, 64, 47, 204, 176, 137,
            172, 194, 4,
        ];
        let fc = FunctionCall::from_raw_bytes(&raw).unwrap();
        dbg!(fc);
    }
}
