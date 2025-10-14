const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// This function runs every minute to check for scheduled notifications
exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Riyadh') // Change to your timezone
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const oneMinuteAgo = admin.firestore.Timestamp.fromMillis(
        now.toMillis() - 60000
      );

      // Query for notifications that should be sent now
      const notificationsSnapshot = await admin
        .firestore()
        .collection('scheduled_notifications')
        .where('sent', '==', false)
        .where('scheduledTime', '<=', now.toDate())
        .where('scheduledTime', '>=', oneMinuteAgo.toDate())
        .get();

      if (notificationsSnapshot.empty) {
        console.log('No notifications to send');
        return null;
      }

      const promises = [];

      notificationsSnapshot.forEach((doc) => {
        const notification = doc.data();
        
        // Filter out null or undefined tokens
        const validTokens = (notification.studentTokens || []).filter(
          (token) => token && token.trim() !== ''
        );

        if (validTokens.length === 0) {
          console.log(`No valid tokens for notification ${doc.id}`);
          return;
        }

        // Create the notification message
        const message = {
          notification: {
            title: notification.title || 'Class Starting Soon!',
            body: notification.body || 'Time to mark attendance!',
          },
          data: {
            courseId: notification.courseId || '',
            classId: notification.classId || '',
            courseName: notification.courseName || '',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'class_notifications',
              sound: 'default',
              priority: 'high',
            },
          },
          tokens: validTokens,
        };

        // Send the notification
        const sendPromise = admin
          .messaging()
          .sendMulticast(message)
          .then((response) => {
            console.log(
              `Successfully sent notification ${doc.id}:`,
              response.successCount,
              'messages sent'
            );
            
            // Mark as sent
            return doc.ref.update({ sent: true, sentAt: now.toDate() });
          })
          .catch((error) => {
            console.error('Error sending notification:', error);
          });

        promises.push(sendPromise);
      });

      await Promise.all(promises);
      console.log('All notifications processed');
      return null;
    } catch (error) {
      console.error('Error in sendScheduledNotifications:', error);
      return null;
    }
  });

// Optional: Clean up old sent notifications (runs daily at midnight)
exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 0 * * *') // Daily at midnight
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotificationsSnapshot = await admin
        .firestore()
        .collection('scheduled_notifications')
        .where('sent', '==', true)
        .where('sentAt', '<', thirtyDaysAgo)
        .get();

      const batch = admin.firestore().batch();
      oldNotificationsSnapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Deleted ${oldNotificationsSnapshot.size} old notifications`);
      return null;
    } catch (error) {
      console.error('Error cleaning up notifications:', error);
      return null;
    }
  });

// Optional: Manual trigger for testing
exports.testNotification = functions.https.onRequest(async (req, res) => {
  try {
    // Get a sample student token for testing
    const usersSnapshot = await admin
      .firestore()
      .collection('users')
      .where('role', '==', 'student')
      .where('fcmToken', '!=', null)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      res.status(404).json({ 
        success: false, 
        error: 'No students with FCM tokens found' 
      });
      return;
    }

    const studentToken = usersSnapshot.docs[0].data().fcmToken;

    const testMessage = {
      notification: {
        title: 'Test Notification',
        body: 'This is a test notification from Cloud Functions!',
      },
      data: {
        test: 'true',
        timestamp: new Date().toISOString(),
      },
      token: studentToken,
    };

    const response = await admin.messaging().send(testMessage);
    res.json({ 
      success: true, 
      messageId: response,
      sentTo: usersSnapshot.docs[0].data().name 
    });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

