# Waves blockchain — PostgreSQL sync scripts 

1. Clone the repository, install dependencies.
   ```bash
   npm install
   ```
2. Create `config.yml` file in the project, using `config.example.yml` for reference.
3. ⬇️ To download a range of blocks to database:
   ```bash
   npm run download {start} {end},
   # for example
   npm run download 1 100000
   ```
   Blocks from the range get inserted in a single transaction, so either all get inserted, or none. In our experience ranges of 10000—100000 work best.

4. 🔄 To keep your database up-to-date: 
   ```bash
   npm run update
   ```
   This is a continuous script, so you may want to run it in the background.