CREATE OR REPLACE FUNCTION delete_order_if_orphan (order_id varchar)
  RETURNS bool
AS $$
BEGIN
  DELETE FROM orders
  WHERE id = order_id;
  RETURN TRUE;
EXCEPTION
  WHEN foreign_key_violation THEN
  RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_orders_after_tx ()
  RETURNS TRIGGER
AS $$
BEGIN
  PERFORM
    delete_order_if_orphan (old.order1);
  PERFORM
    delete_order_if_orphan (old.order2);
  RETURN NULL;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_orphan_orders ON txs_7;

CREATE TRIGGER delete_orphan_orders AFTER DELETE ON txs_7 FOR EACH ROW EXECUTE PROCEDURE delete_orders_after_tx ();

