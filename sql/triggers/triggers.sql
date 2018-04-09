CREATE OR REPLACE FUNCTION on_block_insert ()
  RETURNS TRIGGER
AS $$
BEGIN
  PERFORM insert_all (new.b);
	return new;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION on_block_update ()
  RETURNS TRIGGER
AS $$
BEGIN
  delete from blocks where height = new.height;
	PERFORM insert_all (new.b);
	return new;
END
$$
LANGUAGE plpgsql;

-- triggers to insert/update structured block to tables on raw insert/update
CREATE TRIGGER block_insert_trigger AFTER INSERT ON blocks_raw FOR EACH ROW EXECUTE PROCEDURE on_block_insert ();
CREATE TRIGGER block_update_trigger AFTER UPDATE 	ON blocks_raw FOR EACH row EXECUTE PROCEDURE on_block_update ();

-- for delete simple rule suffices
CREATE RULE block_delete AS ON DELETE TO blocks_raw
    DO ALSO DELETE FROM blocks WHERE height = OLD.height;