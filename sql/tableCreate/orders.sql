CREATE TABLE IF NOT EXISTS orders (
    id varchar PRIMARY KEY,
    sender_public_key varchar NOT NULL,
    matcher_public_key varchar NOT NULL,
    order_type varchar NOT NULL,
    price_asset varchar NOT NULL,
    amount_asset varchar NOT NULL,
    price bigint NOT NULL,
    amount bigint NOT NULL,
    time_stamp timestamp NOT NULL,
    expiration timestamp NOT NULL,
    matcher_fee bigint NOT NULL,
    signature varchar NOT NULL
);

