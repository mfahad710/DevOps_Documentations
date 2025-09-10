# Scenario

In our `users` collection, the `email_address` field contains duplicate values caused by **case sensitivity**. For example, one user may have `fort@fortrans.com` while another has `FORT@FORTRANS.COM`. We want to ensure that email addresses are unique across all users, regardless of letter case.

The script identifies duplicate email addresses in the collection and generates a **CSV file** with the results.

> **This script can also be adapted to detect duplicates in other fields**

## How Script Runs

**Create the file**

```bash
touch Fetch-Duplicate-Field.js
```

**Open in Editor**

```bash
vi Fetch-Duplicate-Field.js
```

> **Add Content on the file**

**Install the Neccesaary Packages**

```bash
npm install mongodb csv-writer fs
```

**Run the script**

```bash
node Fetch-Duplicate-Field.js
```