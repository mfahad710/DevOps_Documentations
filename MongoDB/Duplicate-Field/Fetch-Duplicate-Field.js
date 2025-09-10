// Requires Node.js and the following packages: mongodb, csv-writer, fs
const { MongoClient } = require('mongodb');
const fs = require('fs');
const csv = require('csv-writer').createObjectCsvWriter;

async function findDuplicateEmailsAndGenerateCSV(mongoUri, dbName, collectionName, outputPath) {
  const client = new MongoClient(mongoUri);

  try {
    await client.connect();
    const db = client.db(dbName);
    const collection = db.collection(collectionName);

    const duplicates = await collection.aggregate([
      { $addFields: { lowercaseEmail: { $toLower: "$email_address" } } },
      { $group: {
        _id: "$lowercaseEmail",
        count: { $sum: 1 },
        users: { $push: { id: "$_id", email_address: "$email_address" } }
      }},
      { $match: { count: { $gt: 1 } } },
      { $sort: { count: -1 } }
    ]).toArray();

    // Prepare data for CSV
    const csvData = [];
    duplicates.forEach(group => {
      group.users.forEach(user => {
        csvData.push({
          lowercaseEmail: group._id,
          count: group.count,
          userId: user.id.toString(),
          email: user.email_address
        });
      });
    });

    // Write to CSV
    const csvWriter = csv({
      path: outputPath,
      header: [
        {id: 'lowercaseEmail', title: 'Lowercase Email'},
        {id: 'count', title: 'Duplicate Count'},
        {id: 'userId', title: 'User ID'},
        {id: 'email', title: 'Original Email'}
      ]
    });

    await csvWriter.writeRecords(csvData);
    console.log(`CSV file has been written to ${outputPath}`);

  } catch (error) {
    console.error('An error occurred:', error);
  } finally {
    await client.close();
  }
}

// Example usage
findDuplicateEmailsAndGenerateCSV('<CONNECTION-STRING>', 'fort', 'users', 'duplicate_emails.csv');
