# Bitbucket API Tokens & App Password

## API Token
  
API tokens are single purpose access tokens with scoped user access (specified at the time of creation). These tokens can be useful for scripting, CI/CD tools, and testing Bitbucket Connect applications while they are in development.

### Create an API token

To create an App token:

- Select the **Settings** cog in the upper-right corner of the top navigation bar.
- Under **Personal settings**, select **Atlassian account settings**.
- Select the **Security** tab on the top navigation bar.
- Select **Create and manage API tokens**.
- Select **Create API token with scopes**. 
- Give the API token a name and an expiry date, usually related to the application that will use the token and select **Next**.
- Select **Bitbucket** as the app and select **Next**.
- Select the scopes (permissions) the API token needs and select **Next**. For detailed descriptions of each permission, see: API Token permissions. **Note**: This step is required for your API token to access Bitbucket APIs or perform Git commands.
- Review your token and select the **Create token** button. The page will display the New **API token**.
- Copy the generated API token and either record or paste it into the application you want to give access. 

> **The token is only displayed once and can't be retrieved later.**

### Convert in Base64

Example API Token
```bash
BHATT3xFfGF0rKCrvpv2trRKYxxyaNLJRxeBWw_FK5QMl066NnC5SC4Uy4Ts0EZcp16Y0UIdOQm2EQBxRI1A_xCALwyJ2CnAjzMyOz5UmtUpGUS6cj3Hdywlr9JpX_I_yd1dkBT3txa4K7eMe918OHjLpLUxDhoT68B0JEzMuvygXKnfgApQyJk=6A60DA1F
```

Convert this token in base64 as,

**Format** 
```bash 
<atlassian_account_email>:<token>
```

```bash
fort@fortrans.com:BHATT3xFfGF0rKCrvpv2trRKYxxyaNLJRxeBWw_FK5QMl066NnC5SC4Uy4Ts0EZcp16Y0UIdOQm2EQBxRI1A_xCALwyJ2CnAjzMyOz5UmtUpGUS6cj3Hdywlr9JpX_I_yd1dkBT3txa4K7eMe918OHjLpLUxDhoT68B0JEzMuvygXKnfgApQyJk=6A60DA1F
```

**Encode this token through https://www.base64encode.org/ or any base64 encode tool**

Converted Token

```bash
Zm9ydEBmb3J0cmFucy5jb206QkhBVFQzeEZmR0YwcktDcnZwdjJ0clJLWXh4eWFOTEpSeGVCV3dfRks1UU1sMDY2Tm5DNVNDNFV5NFRzMEVaY3AxNlkwVUlkT1FtMkVRQnhSSTFBX3hDQUx3eUoyQ25BanpNeU96NVVtdFVwR1VTNmNqM0hkeXdscjlKcFhfSV95ZDFka0JUM3R4YTRLN2VNZTkxOE9IakxwTFV4RGhvVDY4QjBKRXpNdXZ5Z1hLbmZnQXBReUprPTZBNjBEQTFG
```

## Bitbucket App Password

App passwords are user-based access tokens for scripting tasks and integrating tools (such as CI/CD tools) with Bitbucket Cloud. App passwords are designed to be used for a single purpose with limited permissions, so they don't require two-step verification (2SV, also known as two-factor authentication or 2FA).

App passwords are tied to an individual account's credentials and should not be shared. By sharing your App password you're giving direct, authenticated access to everything that password has permissions to do with the Bitbucket APIs.

### App passwords features

- They can be used to authenticate API calls.
- They have limited permissions (scopes), specified when the App password is created.
- They are intended to be single purpose, rather than reusable.
- They are encrypted on our database and can't be viewed by anyone.

### Create an App password

To create an App password:

- Select the **Settings** cog in the upper-right corner of the top navigation bar.
- Under **Personal settings**, select **Personal Bitbucket settings**.
- On the left sidebar, select **App passwords**.
- Select **Create app password**.
- Give the App password a name, usually related to the application that will use the password.
- Select the permissions the App password needs. For detailed descriptions of each permission, see: App password permissions.
- Select the **Create** button. The page will display the **New app password** dialog.
- Copy the generated password and either record or paste it into the application you want to give access. The password is only displayed once and can't be retrieved later.

### Convert in Base64

Example API Password
```bash
BNBBrNcYNWXAVxgLD3rD9LjcHcZVD5D5D4C4
```

Convert this token in base64 as,

**Format** 
```bash 
<bitbucket_username>:<token>
```

```bash
MFahad1667:BNBBrNcYNWXAVxgLD3rD9LjcHcZVD5D5D4C4
```

**Encode this token through https://www.base64encode.org/ or any base64 encode tool**

Converted Token

```bash
TUZhaGFkMTY2NzpCTkJCck5jWU5XWEFWeGdMRDNyRDlMamNIY1pWRDVENUQ0QzQ=
```