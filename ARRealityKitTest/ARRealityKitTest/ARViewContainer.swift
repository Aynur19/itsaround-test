//
//  ARViewContainer.swift
//  ARRealityKitTest
//
//  Created by Aynur Nasybullin on 02.11.2024.
//

import SwiftUI
import RealityKit
import ARKit

fileprivate let objectPath = "dzinka_rena_rouge.usdz"

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        
        addCouchingOverlay(arView: arView)
        loadModelEntityToARView(arView: arView, context: context)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> ARCoordinator {
        ARCoordinator()
    }
    
    
    func loadModelEntityToARView(arView: ARView, context: Context) {
        Entity
            .loadModelAsync(named: objectPath)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Model loading error: \(error)")
                    }
                },
                receiveValue: { modelEntity in
                    context.coordinator.loadModelEntityToARView(arView: arView, modelEntity: modelEntity)
                }
            )
            .store(in: &context.coordinator.cancellables)
    }
}


extension ARViewContainer {
    private func addCouchingOverlay(arView: ARView) {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
    }
}
