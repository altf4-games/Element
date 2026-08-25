//
//  AtlasView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import MapKit
import SwiftUI

/// A bonus screen that plots every discovered element on a world map at a
/// coordinate deterministically derived from its name — a "where in the
/// world was this discovered" flourish, not core to the combining loop.
/// Demonstrates `Map`, custom annotations, map selection, and
/// `CLLocationManager`'s permission flow.
struct AtlasView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 15, longitude: 10),
            span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 150)
        )
    )
    @State private var selectedElement: Element?

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, selection: $selectedElement) {
                ForEach(viewModel.discovered) { element in
                    Annotation(element.name, coordinate: coordinate(for: element)) {
                        pin(for: element)
                    }
                    .tag(element)
                }

                if let coordinate = locationManager.coordinate {
                    Annotation("You", coordinate: coordinate) {
                        Image(systemName: "location.fill")
                            .padding(6)
                            .background(Circle().fill(.blue))
                            .foregroundStyle(.white)
                    }
                }
            }
            .mapStyle(.standard)
            .navigationTitle("Atlas")
            .overlay(alignment: .bottomTrailing) {
                Button {
                    locationManager.requestLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .padding(14)
                        .background(.thinMaterial, in: Circle())
                        .shadow(radius: 3)
                }
                .padding()
            }
            .sheet(item: $selectedElement) { element in
                NavigationStack {
                    ElementDetailView(element: element)
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func pin(for element: Element) -> some View {
        Text(element.emoji)
            .font(.system(size: 20))
            .padding(6)
            .background(Circle().fill(Color(hex: element.colorHex)))
            .shadow(radius: 3)
    }

    private func coordinate(for element: Element) -> CLLocationCoordinate2D {
        let seed = element.atlasCoordinateSeed
        let latitude = (seed.latFraction * 160) - 80
        let longitude = (seed.lonFraction * 340) - 170
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
