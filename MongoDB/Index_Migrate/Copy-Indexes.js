const { MongoClient } = require('mongodb');

// Cluster connection string
// Replace <USERNAME> and <PASSWORD> with your MongoDB Atlas credentials
const uri = 'mongodb+srv://<USERNAME>:<PASSWORD>@fort-db.etprb.mongodb.net/';

const sourceDbName = 'fort';
const targetDbName = 'fort-secondary';

async function copyIndexes() {
  const client = new MongoClient(uri);

  try {
    await client.connect();
    const sourceDb = client.db(sourceDbName);
    const targetDb = client.db(targetDbName);

    const collections = await sourceDb.listCollections().toArray();

    for (const { name: collName } of collections) {
      const sourceCollection = sourceDb.collection(collName);
      const targetCollection = targetDb.collection(collName);

      const sourceIndexes = await sourceCollection.indexes();
      const targetIndexes = await targetCollection.indexes();
      const existingIndexNames = new Set(targetIndexes.map(i => i.name));

      for (const index of sourceIndexes) {
        if (index.name === '_id_') continue;

        if (existingIndexNames.has(index.name)) {
          console.log(`Skipping existing index '${index.name}' on '${collName}'`);
          continue;
        }

        try {
          // Only add options if they are defined and valid
          const indexOptions = {};
          if (typeof index.unique === 'boolean') indexOptions.unique = index.unique;
          if (typeof index.sparse === 'boolean') indexOptions.sparse = index.sparse;
          if (typeof index.background === 'boolean') indexOptions.background = index.background;
          if (typeof index.expireAfterSeconds === 'number') indexOptions.expireAfterSeconds = index.expireAfterSeconds;
          indexOptions.name = index.name;

          await targetCollection.createIndex(index.key, indexOptions);
          console.log(`Created index '${index.name}' on '${collName}'`);
        } catch (err) {
          console.error(`Failed to create index '${index.name}' on '${collName}':`, err.message);
        }
      }
    }

    console.log('Index copying completed.');
  } catch (err) {
    console.error('Error during index copy:', err.message);
  } finally {
    await client.close();
  }
}

copyIndexes();