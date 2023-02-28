#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("LoadConfigFailed: {0}")]
    LoadConfigFailed(#[from] envy::Error),

    #[error("InvalidMessage: {0}")]
    InvalidMessage(String),

    #[error("DbDieselError: {0}")]
    DbDieselError(#[from] diesel::result::Error),

    #[error("DeadpoolError: {0}")]
    DeadpoolError(String),

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

    #[error("InconsistDataError: {0}")]
    InconsistDataError(String),
}

// impl done manually because InteractError is not Sync
impl From<deadpool_diesel::InteractError> for Error {
    fn from(err: deadpool_diesel::InteractError) -> Self {
        Error::DeadpoolError(err.to_string())
    }
}
