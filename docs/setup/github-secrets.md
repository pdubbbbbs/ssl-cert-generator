# Setting Up GitHub Secrets

## Email Notification Secrets

For the GitHub Actions email notifications to work, you need to configure these secrets:

| Secret Name | Description | Example |
|------------|-------------|----------|
| SMTP_SERVER | SMTP server address | smtp.gmail.com |
| SMTP_PORT | SMTP server port | 587 |
| SMTP_USERNAME | Your email address | your.email@gmail.com |
| SMTP_PASSWORD | App-specific password | 16-character password |
| NOTIFICATION_EMAIL | Recipient email | your.email@gmail.com |

## Steps to Add Secrets

1. Navigate to your repository's settings
2. Go to Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Add each secret one by one

## Security Best Practices

- Never commit secrets to the repository
- Use app-specific passwords when possible
- Regularly rotate passwords
- Monitor GitHub Actions logs for any issues

## Verification

To verify your secrets are working:

```bash
# Make a test commit
echo "# Test commit" >> README.md
git commit -am "test: trigger GitHub Actions"
git push origin master
```

The workflow will trigger and send email notifications based on the result.
