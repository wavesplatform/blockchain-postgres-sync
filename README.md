# Waves blockchain — PostgreSQL sync scripts 

A set of scripts to download and update Waves blockchain history data into a PostgreSQL database.

## Usage

1. Clone the repository, install dependencies.
   ```bash
   npm install
   ```
2. Create `config.yml` file in the project, using `config.example.yml` for reference.
3. In PostgreSQL, create empty database, initialize it using `schema.sql` in the project root
4. ⬇️ To download a range of blocks to database:
   ```bash
   npm run download {start} {end},
   # for example
   npm run download 1 100000
   ```
   Blocks from the range get inserted in a single transaction, so either all get inserted, or none. In our experience ranges of 10000—100000 work best.

5. 🔄 To keep your database up-to-date: 
   ```bash
   npm run update
   ```
   This is a continuous script, so you may want to run it in the background. We recommend using some kind of process manager (e.g. `pm2`) to restart the process on crash.