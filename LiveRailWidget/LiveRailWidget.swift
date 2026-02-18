//
//  LiveRailWidget.swift
//  LiveRailWidget
//
//  Widget bundle entry point
//

import WidgetKit
import SwiftUI

@main
struct LiveRailWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDepartureWidget()
        TrainLiveActivity()
    }
}
