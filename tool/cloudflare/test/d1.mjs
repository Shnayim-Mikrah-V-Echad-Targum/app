// The D1 calls the Worker makes, over node:sqlite, for the tests: the SQL runs
// on real SQLite, as it would on D1. A batch is one transaction, and returns
// each statement's rows, as D1's does for a statement with RETURNING.
export function d1(database) {
  const prepare = (sql) => {
    let values = [];
    return {
      sql,
      bind(...args) {
        values = args;
        return this;
      },
      first() {
        return database.prepare(sql).get(...values) ?? null;
      },
      all() {
        return { results: database.prepare(sql).all(...values) };
      },
      run() {
        return { success: true, results: database.prepare(sql).all(...values) };
      },
    };
  };
  return {
    prepare,
    async batch(statements) {
      database.exec('BEGIN');
      try {
        const results = statements.map((statement) => statement.run());
        database.exec('COMMIT');
        return results;
      } catch (error) {
        database.exec('ROLLBACK');
        throw error;
      }
    },
  };
}
