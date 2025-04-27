# GitHub Actions Email Notification Setup

To configure email notifications, you need to add the following secrets to your GitHub repository:

1. Go to your repository's Settings > Secrets and variables > Actions > New repository secret

2. Add these secrets:

   - SMTP_SERVER
     - Description: Your SMTP server address
     - Example: smtp.gmail.com

   - SMTP_PORT
     - Description: SMTP server port
     - Example: 587 (for TLS)

   - SMTP_USERNAME
     - Description: Your email address
     - Example: your.email@gmail.com

   - SMTP_PASSWORD
     - Description: Your email password or app-specific password
     - For Gmail: Use an App Password (Settings > Security > 2-Step Verification > App Passwords)

   - NOTIFICATION_EMAIL
     - Description: Email address to receive notifications
     - Example: your.email@gmail.com

## For Gmail Users:

1. Enable 2-Step Verification:
   - Go to Google Account > Security
   - Enable 2-Step Verification

2. Create App Password:
   - Go to Google Account > Security > App Passwords
   - Select "Mail" and "Other (Custom name)"
   - Name it "GitHub Actions"
   - Use the generated 16-character password for SMTP_PASSWORD

## Testing

After setting up the secrets:
1. Make a small change to any file
2. Commit and push to trigger the workflow
3. Check your email for notifications

Would you like me to help you set up these secrets in your repository?
