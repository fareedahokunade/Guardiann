package com.example.guardian;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleObserver;
import androidx.lifecycle.OnLifecycleEvent;
import androidx.lifecycle.ProcessLifecycleOwner;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;



public class MainActivity extends FlutterActivity {
    private Intent forService;
    private AppLifecycleListener appLifecycleListener;
    private BroadcastReceiver panicActionReceiver;

    public String getFlutterEngineId() {
        return "my_engine_id";
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        appLifecycleListener = new AppLifecycleListener();

        forService = new Intent(MainActivity.this, MyService.class);

        new MethodChannel(getFlutterEngine().getDartExecutor(), "com.example.guardian")
                .setMethodCallHandler((methodCall, result) -> {
                    if ("startService".equals(methodCall.method)) {
                        startService();
                        result.success("Service Started");
                    }
                });

        panicActionReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if ("com.example.guardian.PANIC_ACTION_TRIGGERED".equals(intent.getAction())) {
                    if (appLifecycleListener.isAppInBackground()) {
                        new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), "com.example.guardian/channel")
                                .invokeMethod("triggerPanicAction", null);
                    }
                }
            }
        };
        registerReceiver(panicActionReceiver, new IntentFilter("com.example.guardian.PANIC_ACTION_TRIGGERED"));
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterReceiver(panicActionReceiver);
        stopService(forService);
    }

    private void startService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(forService);
        } else {
            startService(forService);
        }
    }
}

class AppLifecycleListener implements LifecycleObserver {
    private boolean appInBackground = true;

    public AppLifecycleListener() {
        ProcessLifecycleOwner.get().getLifecycle().addObserver(this);
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    public void onMoveToForeground() {
        appInBackground = false;
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    public void onMoveToBackground() {
        appInBackground = true;
    }

    public boolean isAppInBackground() {
        return appInBackground;
    }
}
