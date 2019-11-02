UPDATE waves_data SET height=0 WHERE height=1;

ALTER TABLE public.waves_data DROP CONSTRAINT waves_data_fk;
