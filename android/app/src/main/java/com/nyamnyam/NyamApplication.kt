package com.nyamnyam

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * 폰 앱의 Hilt 루트(ADR-06). :wear는 따로 자기 루트를 둔다.
 */
@HiltAndroidApp
class NyamApplication : Application()
