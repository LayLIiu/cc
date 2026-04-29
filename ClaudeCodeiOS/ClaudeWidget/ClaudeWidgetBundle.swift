//
//  ClaudeWidgetBundle.swift
//  ClaudeWidget
//
//  Created by liujie on 2026/4/29.
//

import WidgetKit
import SwiftUI

@main
struct ClaudeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeWidget()
        ClaudeWidgetControl()
        ClaudeWidgetLiveActivity()
    }
}
