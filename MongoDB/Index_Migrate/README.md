# Scenario
We have two databases within the same MongoDB Atlas cluster: `fort` and `fort-secondary`. Both databases contain the same collections; however, only the fort database has indexes that optimize query performance. Now, we want to replicate all the indexes from the `fort` database to the `fort-secondary` database.

## How Script Runs

**Create the file**

```bash
touch Copy-Indexes.js
```
    
**Open in Editor**

```bash
vi Copy-Indexes.js
```

> **Add Content on the file**

**Install the Neccesaary Packages**

```bash
npm install mongodb
```

**Run the script**

```bash
node Copy-Indexes.js
```