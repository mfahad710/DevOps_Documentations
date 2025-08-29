# 🌐 Website Monitoring Alert

This Script provides a **Website Monitoring Alert** built in **Node.js**.  
It periodically checks the availability of defined websites and sends **email alerts** via **SendGrid** when a site is down or unresponsive.

## Overview

- Uses **Axios** to send HTTP requests for website monitoring.  
- Implements **SendGrid** for sending email notifications.  
- Detects downtime caused by:
  - Server errors (status >= 500)
  - Request timeout
  - Connection errors (e.g., refused, not found)

## Prerequisites

Before running the script, ensure you have:

- [Node.js](https://nodejs.org/) installed  
- A **SendGrid API Key**  
- Valid **recipient email address**  
- Installed project dependencies  

```bash
npm install axios @sendgrid/mail
```

## Dependencies

```javascript
const axios = require('axios');
const sgMail = require('@sendgrid/mail');
```

- `axios` → For HTTP requests to check website availability  
- `@sendgrid/mail` → For sending email notifications  

## Configuration

- **SendGrid API Key** → Required for email delivery  
- **Recipient Email** → Default: `muhammad.fahad@gmail.com`  
- **Sender Email** → Default: `mail@fortrans.com`  
- **Timeout** → 30 seconds 

## Script

```javascript
const axios = require('axios');
const sgMail = require('@sendgrid/mail');

class WebsiteMonitor {
    constructor(sendgridApiKey, recipientEmail = 'muhammad.fahad@gmail.com') {
        this.sendgridApiKey = sendgridApiKey;
        this.recipientEmail = recipientEmail;
        this.senderEmail = 'mail@fortrans.com';
        
        // Configure SendGrid
        sgMail.setApiKey(this.sendgridApiKey);
        
        // List of websites to monitor
        this.websites = [
            'https://sandbox.fortrans.com/',
            'https://api.fortrans.com/heartbeat',
            'https://dummy.fortrans.com/heartbeat',
        ];
        
        // Request timeout in milliseconds (30 seconds)
        this.timeout = 30000;
    }
    
    async checkWebsite(url) {
        try {
            const response = await axios.get(url, {
                timeout: this.timeout,
                validateStatus: (status) => status < 500
            });
            
            if (response.status === 200) {
                return { isUp: true, message: `Website is up (Status: ${response.status})` };
            } else {
                return { isUp: false, message: `Website returned status code: ${response.status}` };
            }
        } catch (error) {
            if (error.code === 'ECONNABORTED') {
                return { isUp: false, message: 'Request timed out' };
            } else if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
                return { isUp: false, message: 'Connection error - website may be down' };
            } else {
                return { isUp: false, message: `Request failed: ${error.message}` };
            }
        }
    }
    
    async sendEmailNotification(failedWebsites) {
        if (Object.keys(failedWebsites).length === 0) {
            return;
        }
        
        const subject = `Website Monitoring Alert - ${Object.keys(failedWebsites).length} site(s) down`;
        
        let htmlContent = `
        <html>
        <body>
            <h2>Website Monitoring Alert</h2>
            <p>The following websites are currently down or experiencing issues:</p>
            <ul>
        `;
        
        let textContent = `Website Monitoring Alert\n\nThe following websites are down:\n\n`;
        
        for (const [website, error] of Object.entries(failedWebsites)) {
            htmlContent += `<li><strong>${website}</strong>: ${error}</li>\n`;
            textContent += `• ${website}: ${error}\n`;
        }
        
        htmlContent += `
            </ul>
            <p>Checked at: ${new Date().toLocaleString()}</p>
        </body>
        </html>
        `;
        
        const msg = {
            to: this.recipientEmail,
            from: this.senderEmail,
            subject: subject,
            text: textContent,
            html: htmlContent,
            categories: ['Site_Monitoring']
        };
        
        try {
            const response = await sgMail.send(msg);
            console.log(`Email sent successfully! Status code: ${response[0].statusCode}`);
        } catch (error) {
            console.error('Error sending email:', error.message);
            if (error.response) {
                console.error('SendGrid error details:', error.response.body);
            }
        }
    }
    
    async monitorWebsites() {
        console.log(`Starting website monitoring at ${new Date().toLocaleString()}`);
        console.log(`Monitoring ${this.websites.length} websites...`);
        
        const failedWebsites = {};
        const promises = this.websites.map(async (url) => {
            process.stdout.write(`Checking ${url}... `);
            const result = await this.checkWebsite(url);
            
            if (result.isUp) {
                console.log('UP');
            } else {
                console.log(`DOWN - ${result.message}`);
                failedWebsites[url] = result.message;
            }
        });
        
        // Wait for all checks to complete
        await Promise.all(promises);
        
        // Send email notification if any websites are down
        if (Object.keys(failedWebsites).length > 0) {
            console.log(`\n${Object.keys(failedWebsites).length} website(s) are down. Sending email notification...`);
            await this.sendEmailNotification(failedWebsites);
        } else {
            console.log('\nAll websites are up and running!');
        }
        
        return failedWebsites;
    }
}

async function main() {
    // Configuration
    const SENDGRID_API_KEY = '<SENDGRID_API_KEY>';
    
    // Initialize monitor
    const monitor = new WebsiteMonitor(SENDGRID_API_KEY);
    
    // Run monitoring
    try {
        await monitor.monitorWebsites();
    } catch (error) {
        console.error('Error during monitoring:', error.message);
    }
}

// Run if this file is executed directly
if (require.main === module) {
    main();
}

module.exports = WebsiteMonitor;
```

## How to Run

1. Replace the **SendGrid API Key** in `main()`:
   ```javascript
   const SENDGRID_API_KEY = '<YOUR_SENDGRID_API_KEY>';
   ```

2. Run the script:
   ```bash
   node WebsiteMonitor.js
   ```

3. If a website is down, you’ll receive an email alert.

###  Example Console Output

```bash
Starting website monitoring at 8/29/2025, 10:00:00 PM
Monitoring 3 websites...
Checking https://sandbox.fortrans.com/... UP
Checking https://api.fortrans.com/heartbeat... UP
Checking https://dummy.fortrans.com/heartbeat... DOWN - Request timed out

1 website(s) are down. Sending email notification...
Email sent successfully! Status code: 202
```

## Security Considerations

- Keep your **SendGrid API Key** secret. Do not hardcode it in production. Use environment variables instead:
  ```bash
  export SENDGRID_API_KEY="<your_key_here>"
  ```
