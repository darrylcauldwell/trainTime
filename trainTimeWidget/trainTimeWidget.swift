//
//  trainTimeWidget.swift
//  trainTimeWidget
//
//  Widget bundle entry point
//

import WidgetKit
import SwiftUI

@main
struct trainTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDepartureWidget()
        TrainLiveActivity()
    }
}
