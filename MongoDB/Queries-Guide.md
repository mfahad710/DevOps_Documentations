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
