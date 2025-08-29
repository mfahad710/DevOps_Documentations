# 📄 Expiry Date Alert Script

## Overview

This **Python** script monitors credential expiry dates stored in a **Google Sheet** and sends email alerts using **SendGrid** if credentials are about to expire.

It helps ensure that critical credentials (API keys, certificates, etc.) are renewed before expiration to avoid service disruptions.

## Features

- Connects to a **Google Sheet** to retrieve a list of credentials.
- Calculates how many days remain until expiry.
- Sends **email alerts via SendGrid** if a credential is expiring within a defined threshold.
- Skips alerts for credentials marked as **"Closed"**.
- Configurable alert threshold, email addresses, and Google Sheet details.

## Configuration Parameters

- `alert_threshold_days`: Number of days before expiry to trigger an alert (default = `10`).
- `sendgrid_api_key`: API key for SendGrid.
- `from_email`: Sender email address (configured for SendGrid).
- `to_email`: Recipient email address for expiry alerts.
- `spreadsheet_id`: Google Sheets ID where credentials are stored.
- `sheet_name`: Name of the sheet containing expiry data.

## Google Sheet Format

The script expects the following columns in the sheet:

- **Name** – Name/identifier of the credential.
- **Expiry Date** – Expiry date in `YYYY-MM-DD` format.
- **Status** – Either `"Open"` (active, monitored) or `"Close"` (inactive, ignored).

| Name  | Expiry Date | Status  |
|----------------------|----------------------------|------------|
| API_Key_123          | 2025-09-10                 | Open       |
| Cert_ABC             | 2025-08-15                 | Close      |
| Token_Service_XYZ    | 2025-09-25                 | Open       |

## Google Sheets Authentication

To access the Google Sheet, this script requires a **Service Account JSON key** for authentication.  

### Steps to Set Up:
1. Go to **Google Cloud Console** → [https://console.cloud.google.com/](https://console.cloud.google.com/).  
2. Create a **new project** (or select an existing one).  
3. Enable the following APIs:
   - Google Sheets API  
   - Google Drive API  
4. Create a **Service Account** under IAM & Admin → Service Accounts.  
5. Generate a **JSON key file** for the Service Account and download it.  
6. Save the file securely (e.g., `/home/ubuntu/drive/scripts/expiryAlerts/expiry-alerts-sheet.json`).

## Dependencies

Install required packages before running the script:

```bash
pip install gspread oauth2client sendgrid
```

## Script

```python
import datetime
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Header

# Configuration
alert_threshold_days = 10
sendgrid_api_key = "<SENDGRID_API_KEY>"
from_email = "mail@fortrans.com"
to_email = "muhammad.fahad@gmail.com"
spreadsheet_id = "<Google_Sheet_ID>"
sheet_name = "<Google_Sheet_Name>"

# Set up Google Sheets API client
def get_google_sheet_data():
    scope = ["https://www.googleapis.com/auth/spreadsheets.readonly", "https://www.googleapis.com/auth/drive.readonly"]
    creds = ServiceAccountCredentials.from_json_keyfile_name("/home/ubuntu/drive/scripts/expiryAlerts/expiry-alerts-sheet-b59fc940c463.json", scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(spreadsheet_id).worksheet(sheet_name)
    data = sheet.get_all_records()
    return data

# Function to send email using SendGrid Python SDK
def send_email(to_email, subject, body):
    message = Mail(
        from_email=from_email,
        to_emails=to_email,
        subject=subject,
        html_content=body
    )

    # Add headers similar
    message.add_header(Header(key="X-SMTPAPI", value='{"category": ["Expiry-Alerts", "Expiry-Alerts"]}'))
    
    try:
        sg = SendGridAPIClient(sendgrid_api_key)
        response = sg.send(message)
        if response.status_code == 202:
            print(f"Email sent successfully to {to_email}.")
        else:
            print(f"Failed to send email. Status code: {response.status_code}, Response: {response.body}")
    except Exception as e:
        print(f"Error occurred: {e}")

# Check each credential for expiry and open status
def check_credentials(credentials):
    today = datetime.datetime.now().date()

    for credential in credentials:
        expiry_date = datetime.datetime.strptime(str(credential["Expiry Date"]), "%Y-%m-%d").date()
        days_until_expiry = (expiry_date - today).days
        status = credential["Status"]

        if days_until_expiry <= alert_threshold_days and status.lower() == "open":
            subject = f"Crendential Expiry Alert: '{credential['Name']}' Expiring Soon"
            body = f"The credential '{credential['Name']}' is set to expire in {days_until_expiry} days, on {expiry_date}. Please take the necessary steps to renew or replace this credential before the expiration date to avoid any service disruption."
            send_email(to_email, subject, body)
        elif days_until_expiry <= alert_threshold_days and status.lower() == "close":
            print(f"Skipping email for {credential['Name']} as the status is closed.")

# Get credentials from Google Sheet and check for expiration
credentials = get_google_sheet_data()
check_credentials(credentials)
```

## Functions

 `get_google_sheet_data()`

Fetches all credential records from Google Sheets.

**Returns:**

A list of dictionaries containing sheet data.

---

`send_email(to_email, subject, body)`

Sends an email using SendGrid.

**Parameters:**

- `to_email (str)`: Recipient email address.
- `subject (str)`: Subject line of the email.
- `body (str)`: HTML content of the email.

**Behavior:**

- Uses the SendGrid API to send email.
- Logs whether the email was successfully sent.
- Handles exceptions if SendGrid fails.

---

`check_credentials(credentials)`

Checks each credential record for expiry and sends alerts if required.

**Parameters:**

- `credentials (list[dict])`: List of credentials fetched from Google Sheets.

**Logic:**

- Get today’s date.
- For each credential:
  - Calculate `days_until_expiry`.
  - If expiry is within threshold and status is `"Open"`, send email alert.
  - If status is `"Close"`, skip sending an alert.

---

🔄 Script Flow

1. **Load credentials** from Google Sheets.  
2. **Calculate days until expiry** for each credential.  
3. If expiry is near **and status = "Open"**, **send email alert**.  
4. **Log actions** (emails sent or skipped credentials).  

## Example Execution

```bash
python3 expiry_alerts.py
```

### Output Example:

```bash
Email sent successfully to muhammad.fahad@gmail.com Skipping email for **TestKey123** as the status is closed.
```

## Security Considerations

- API Keys & Credentials:
  - Avoid hardcoding `sendgrid_api_key` in the script.
  - Use environment variables or a secrets manager.
- Service Account JSON:
  - Protect the Google Sheets service account key file.
- Email Recipients:
  - Ensure `from_email` is verified in SendGrid.
