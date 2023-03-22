use diesel::migration::Migration;
use diesel::{migration, pg::PgConnection, Connection};
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};

use app_lib::{config, db::generate_postgres_url};

const MIGRATIONS: EmbeddedMigrations = embed_migrations!();

fn main() -> anyhow::Result<()> {
    let action = action::parse_command_line()?;
    let dbconfig = config::postgres::load()?;
    let conn = PgConnection::establish(&generate_postgres_url(&dbconfig))?;
    run(action, conn).map_err(|e| anyhow::anyhow!(e))
}

fn run(action: action::Action, mut conn: PgConnection) -> migration::Result<()> {
    use action::Action::*;
    match action {
        ListPending => {
            let list = conn.pending_migrations(MIGRATIONS)?;
            if list.is_empty() {
                println!("No pending migrations.");
            }
            for mig in list {
                println!("Pending migration: {}", mig.name());
            }
        }
        MigrateUp => {
            let list = conn.run_pending_migrations(MIGRATIONS)?;
            if list.is_empty() {
                println!("No pending migrations.");
            }
            for mig in list {
                println!("Applied migration: {}", mig);
            }
        }
        MigrateDown => {
            let mig = conn.revert_last_migration(MIGRATIONS)?;
            println!("Reverted migration: {}", mig);
        }
    }
    Ok(())
}

mod action {
    pub enum Action {
        ListPending,
        MigrateUp,
        MigrateDown,
    }

    impl TryFrom<&str> for Action {
        type Error = ();

        fn try_from(value: &str) -> Result<Self, Self::Error> {
            match value {
                "" | "list" => Ok(Action::ListPending),
                "up" => Ok(Action::MigrateUp),
                "down" => Ok(Action::MigrateDown),
                _ => Err(()),
            }
        }
    }

    pub fn parse_command_line() -> Result<Action, anyhow::Error> {
        let action_str = std::env::args().nth(1).unwrap_or_default();
        let action = action_str.as_str().try_into().map_err(|()| {
            anyhow::anyhow!(
                "unrecognized command line argument: {} (either 'up' or 'down' expected)",
                action_str
            )
        })?;
        Ok(action)
    }
}
