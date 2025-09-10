# MongoDB Queries Guide

### Fetch Emails of Specific Addresses

Query is using a regular expression (`$regex`) to filter documents based on the `email_address` field.

**MongoDB Compass**

```mongodb
{
  "email_address": {
    "$regex": "fortrans\\.com$",
    "$options": "i"
  }
}
```

> Replace `email_address` with the actuall field name

- `email_address` → The field being queried.
- `$regex` → A regular expression filter.
- `fortrans\\.com$` → The regex pattern:
  - `fortrans` → Matches the string "`fortrans`".
  - `\\.` → Escaped dot (`.`) to literally match "`.`" instead of “any character”.
  - `com$` → `$` means end of string, so it must end with "`com`".
  - Full regex matches emails that end with `fortrans.com`
- `$options: "i"` → Makes the regex case-insensitive.

**MongoDB Shell**

```mongodb
db.collection.find({
  email_address: { $regex: /fortrans\.com$/i }
})
```

**Replace `collection` with your actual collection name.**  

In simple words:
This query returns all documents where the email_address ends with fortrans.com (e.g., `admin@fortran.com`, `info@hr.fortrans.com` ) regardless of letter case.

---

### Find Specific word
Mongo shell query to find all users whose email_address contains the word "fort"

```javascript
db.users.find({ email_address: /fort/i })
```

---

### Update Fields

**This query update the multiple user's field**

```bash
db.users.updateMany(
{
  "email_address": {
    "$in": [
      "fort@fortrans.com",
      "fort-admin@fortrans.com"
    ]
  }
},
{$set: {status:"active"}}
)
```

- `db.users`: Targets the **"users"** collection
- `updateMany()`: Updates multiple documents that match the filter criteria
- `email_address`: Field to filter on
- `$in`: Operator that matches documents where `email_address` equals any value in the provided array
- `$set`: Operator that sets the value of a field
- `status`: Field to be updated
- `"active"`: The new value to set

**This query update one user field**

```javascript
db.users.updateOne(
  { _id: "<UUID>",
    name: "fort"
  },
  {
    $set: {
        login_count: "0",
        identifier: "fort"
    }
  }
)
```

**Update specific element in organization array**

This query updates specific elements within an array in the `users` collection

```javascript
db.users.updateMany(
  {
    "organizations.organization": "<UUID>",
    "organizations.name": "NBP"
  },
  {
    $set: {
      "organizations.$[elem].name": "National Bank of Pakistan"
    }
  },
  {
    arrayFilters: [
      { "elem.name": "NBP" }
    ]
  }
)
```

### Delete All Documents in a Collection

To remove all documents but keep the collection structure:

```javascript
db.collection_name.deleteMany({})
```

**Example:**

```javascript
db.orders.deleteMany({})
```

**Delete all other documents except that one using `$ne` or `$nin`**

```javascript
db.collection_name.deleteMany({ _id: { $ne: docToKeep._id } })
```

### Insert Document in Collection

This query insert one user in `users` collection
```javascript
db.users.insertOne( {
    "_id": "<UUID>",
    "deleted": false,
    "created_at": ISODate("2025-03-07T09:47:45.000Z"),
    "name": "<USERNAME>",
    "is_active": true,
    "email_address": "<EMAIL_ADDRESS>"
})
```

**Push license field after the user create**

```javascript
db.users.updateOne( 
    {
        _id: "<UUID>",
        email_address: "<EMAIL_ADDRESS>"
    },
    {
        $push: {
          "license": [ {
                      "_id": "e6c85ac0-0f08-47b7-81d8-0cec73ff8f66",
                      "license_type": "shared",
                      "expiry_at": ISODate("2026-02-13T09:47:45.000Z"),
                      "grace_period": 15,
                      "license_key": "ceb3757b-5053-4df3-8465-9aeaab82255a",
                    } ]
                },
    }
)
```
