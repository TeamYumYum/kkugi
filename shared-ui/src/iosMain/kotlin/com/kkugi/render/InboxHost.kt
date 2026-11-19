package com.kkugi.render

import androidx.compose.ui.window.ComposeUIViewController
import platform.UIKit.UIViewController

fun inboxController(model: InboxModel, actions: InboxActions): UIViewController =
    ComposeUIViewController { SharedInbox(model, actions) }
