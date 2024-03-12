import SwiftUI
import MetalKit
import Metal

struct InstructionsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Start by aiming your phone’s back camera forward during travel. This app will continuously inform you about obstacles in your path. You'll hear descriptions like 'Pole in 3 meters' or 'Car approaching in 5 meters.'" +
                     
                     "\n\nRemember, this app complements but does not replace your usual mobility and navigation tools. It's designed to provide extra situational awareness." +
                     
                     "\n\nIn the event of a fall or collision, our 'Emergency Assist' feature activates. It checks if you need emergency help and, with your confirmation, calls emergency services for immediate assistance. You can turn this feature off in the settings." +

                     "\n\nFor temporary silence, like during conversations, tilt your phone down to pause live voice alerts. Tilt it back up to resume." +

                     "\n\nFeel free to customize audio alerts, haptic feedback, measurement units, and more in the settings to suit your preferences.")
            }
        }.navigationTitle("Instructions")
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Measurement")) {
                    Picker("Measurement System", selection: $settings.measurementSystem) {
                        Text(MeasurementSystem.Metric.rawValue).tag(MeasurementSystem.Metric)
                        Text(MeasurementSystem.Imperial.rawValue).tag(MeasurementSystem.Imperial)
                    }
                }
                Section(header: Text("Audio")) {
                    Toggle(isOn: $settings.audioOutput) {
                        Text("Audio Output")
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Audio Speed")
                            Text(String(format: "%.2f", settings.audioSpeed)).font(.system(size: 14))
                        }
                        
                        Slider(
                            value: $settings.audioSpeed,
                            in: 0...1,
                            step: 0.1,
                            label: {
                                Text("Audio Speed")
                            },
                            minimumValueLabel: {
                                Text("0")
                            },
                            maximumValueLabel: {
                                Text("1")
                            }
                        ).disabled(!settings.audioOutput)
                    }
                }
                
                Section(header: Text("Help & Support")) {
                    NavigationLink(destination: InstructionsView()) {
                        Text("Instructions")
                    }
                }
            }.navigationTitle("Settings")
        }
    }
}
