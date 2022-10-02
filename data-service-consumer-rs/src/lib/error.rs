use warp::reject::Reject;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("LoadConfigFailed: {0}")]
    LoadConfigFailed(#[from] envy::Error),
    #[error("HttpRequestError {0}")]
    HttpRequestError(#[from] reqwest::Error),
    #[error("InvalidMessage: {0}")]
    InvalidMessage(String),
    #[error("DbDieselError: {0}")]
    DbDieselError(#[from] diesel::result::Error),
    #[error("ConnectionPoolError: {0}")]
    ConnectionPoolError(#[from] r2d2::Error),
    #[error("ConnectionError: {0}")]
    ConnectionError(#[from] diesel::ConnectionError),
    #[error("StreamClosed: {0}")]
    StreamClosed(String),
    #[error("StreamError: {0}")]
    StreamError(String),
    #[error("SerializationError: {0}")]
    SerializationError(#[from] serde_json::Error),
    #[error("CursorDecodeError: {0}")]
    CursorDecodeError(#[from] base64::DecodeError),
    #[error("JoinError: {0}")]
    JoinError(#[from] tokio::task::JoinError),
    #[error("IncosistDataError: {0}")]
    IncosistDataError(String),
}

impl Reject for Error {}
