package com.example.guardian;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import android.app.Notification;
import android.app.PendingIntent;

public class MyService extends Service {

    private long lastVolumeChangeTime = 0;
    private final long thresholdMilliseconds = 10000; // Adjusted threshold
    private int rapidChangeCount = 0;
    private BroadcastReceiver volumeChangeReceiver;

    @Override
    public void onCreate() {
        super.onCreate();

        volumeChangeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                final String action = intent.getAction();
                if ("android.media.VOLUME_CHANGED_ACTION".equals(action)) {
                    long currentTime = System.currentTimeMillis();
                    if (lastVolumeChangeTime != 0) {
                        long millisecondsSinceLastChange = currentTime - lastVolumeChangeTime;
                        if (millisecondsSinceLastChange <= thresholdMilliseconds) {
                            rapidChangeCount++;
                            if (rapidChangeCount == 2) {
                                Log.d("VolumeChangeService", "Emergency detected");
                                triggerPanicAction();
                                rapidChangeCount = 0; // Reset count after triggering action
                            }
                        } else {
                            rapidChangeCount = 1; // Reset count if not within threshold
                        }
                    } else {
                        rapidChangeCount = 1;
                    }
                    lastVolumeChangeTime = currentTime;
                }
            }
        };

        IntentFilter filter = new IntentFilter("android.media.VOLUME_CHANGED_ACTION");
        registerReceiver(volumeChangeReceiver, filter);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, "emergency")
                .setContentText("This is running in Background")
                .setContentTitle("Flutter Background")
                .setSmallIcon(R.drawable.icon); // Ensure you have such an icon

        startForeground(101, builder.build());
    }

    private void triggerPanicAction() {
        Intent intent = new Intent(this, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        unregisterReceiver(volumeChangeReceiver); // Unregister receiver to prevent leaks
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
