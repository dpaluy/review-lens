-- Extra databases for the Solid Cache / Queue / Cable gems.
-- Runs once on first Postgres init (empty data directory).
-- The primary database (review_lens_production) is created by POSTGRES_DB.
CREATE DATABASE review_lens_production_cache;
CREATE DATABASE review_lens_production_queue;
CREATE DATABASE review_lens_production_cable;
