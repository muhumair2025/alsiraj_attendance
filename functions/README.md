# Cloud Functions for Al-Siraj Attendance

## Quick Setup

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Deploy to Firebase
```bash
firebase deploy --only functions
```

### 3. Test the Function
Visit the test URL (replace with your project):
```
https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/testNotification
```

## Available Functions

### sendScheduledNotifications
- **Trigger**: Runs every 1 minute
- **Purpose**: Sends notifications to students when class starts
- **Cost**: Free (within 2M invocations/month)

### cleanupOldNotifications
- **Trigger**: Runs daily at midnight
- **Purpose**: Deletes sent notifications older than 30 days
- **Cost**: Free

### testNotification
- **Trigger**: HTTP request
- **Purpose**: Send a test notification to verify setup
- **URL**: `https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/testNotification`

## Configuration

### Change Timezone
Edit `index.js` and update:
```javascript
.timeZone('Asia/Riyadh') // Your timezone here
```

### Change Schedule
Edit the cron expression:
```javascript
.schedule('every 1 minutes') // Can be: 'every 5 minutes', '*/10 * * * *', etc.
```

## Monitoring

### View Logs
```bash
npm run logs
```

Or:
```bash
firebase functions:log --only sendScheduledNotifications
```

### Local Testing
```bash
npm run serve
```

## See Also
- Main documentation: `../CLOUD_FUNCTION_SETUP.md`
- Notification system: `../NOTIFICATION_SYSTEM.md`

