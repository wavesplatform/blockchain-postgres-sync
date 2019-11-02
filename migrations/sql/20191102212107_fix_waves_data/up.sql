UPDATE waves_data SET height=1 WHERE height=0;

ALTER TABLE public.waves_data ADD CONSTRAINT waves_data_fk FOREIGN KEY (height) REFERENCES blocks(height) ON DELETE CASCADE;
