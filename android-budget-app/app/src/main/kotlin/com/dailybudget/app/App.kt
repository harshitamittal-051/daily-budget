package com.dailybudget.app

import android.app.Application
import com.dailybudget.app.work.Notifier
import com.dailybudget.app.work.Scheduler

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Notifier.ensureChannel(this)
        Scheduler.scheduleAll(this)
    }
}
