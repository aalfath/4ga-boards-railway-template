// Waits for Postgres, then runs upstream's migrations and, on an empty
// database only, upstream's seed (which creates the admin from DEFAULT_ADMIN_*
// and stores the sign-up setting). A Postgres advisory lock keeps two
// overlapping Railway deploys from seeding twice.

process.chdir(__dirname);
const initKnex = require('knex');
const knexfile = require('./db/knexfile');

const LOCK_ID = 41233123;
const sleep = (ms) => new Promise((r) => { setTimeout(r, ms); });

(async () => {
  const knex = initKnex({ ...knexfile, pool: { min: 0, max: 4 } });
  let conn;
  let locked = false;
  try {
    for (let i = 1; ; i += 1) {
      try {
        await knex.raw('select 1');
        break;
      } catch (err) {
        if (i >= 90) throw err;
        console.log(`[railway-init] waiting for the database (${err.code || err.message})`);
        await sleep(2000);
      }
    }

    conn = await knex.client.acquireConnection();
    for (let i = 1; ; i += 1) {
      const res = await conn.query('select pg_try_advisory_lock($1) as ok', [LOCK_ID]);
      if (res.rows[0].ok) { locked = true; break; }
      if (i >= 150) throw new Error('timed out waiting for the setup lock');
      if (i === 1) console.log('[railway-init] another deploy is setting up the database; waiting');
      await sleep(2000);
    }

    const isExists = await knex.schema.hasTable(knexfile.migrations.tableName);
    const [, done] = await knex.migrate.latest();
    console.log(`[railway-init] migrations applied: ${done.length}`);
    if (!isExists) {
      await knex.seed.run();
      console.log(`[railway-init] first boot: created admin "${process.env.DEFAULT_ADMIN_USERNAME}", public sign-up ${process.env.DEFAULT_REGISTRATION_ENABLED === 'false' ? 'off' : 'on'}`);
    }
  } finally {
    if (conn) {
      if (locked) await conn.query('select pg_advisory_unlock($1)', [LOCK_ID]).catch(() => {});
      await knex.client.releaseConnection(conn);
    }
    await knex.destroy();
  }
})().catch((err) => {
  console.error('[railway-init] failed:', err);
  process.exit(1);
});
