package com.nyamnyam.wear

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * 워치 앱의 Hilt 루트(ADR-06). 워치는 :core만 의존하고(ADR-05) 서버·인증을 모른다(ADR-02).
 */
@HiltAndroidApp
class NyamWearApplication : Application()
