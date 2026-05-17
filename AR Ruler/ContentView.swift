//
//  ContentView.swift
//  AR Ruler
//
//  Created by Hiren on 06/09/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var distanceText : String = "Tap to add first point"
    @State private var arViewRef: ARView?
    @Environment(\.scenePhase) private var scenePhase   // Track app state
    @State private var hasLaunched = false   // ✅ track first launch

    
    var body: some View {
        ZStack {
            ARRulerView(distanceText: $distanceText, scenePhase: scenePhase)
                .ignoresSafeArea(.all)
            ZStack{
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                
            }
            VStack{
                Spacer()
                
                Text(distanceText)
                    .font(.headline)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}



struct ARRulerView: UIViewRepresentable {
    
//    @Binding var arViewRef: ARView?   // ✅ new binding
    @Binding var distanceText: String
    var scenePhase: ScenePhase

    
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARRulerView
        var startAnchor: AnchorEntity?
        
        init(_ parent: ARRulerView) {
            self.parent = parent
        }
        
        func resetMeasurement(on view: ARView)
        {
            view.scene.anchors.removeAll()
            startAnchor = nil
            DispatchQueue.main.async {
                self.parent.distanceText = "Tap to add first point"
            }
        }
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { }
        
        func handleTap(on view: ARView, at location: CGPoint) {
            // Perform a raycast
            let results = view.raycast(from: location,
                                       allowing: .estimatedPlane,
                                       alignment: .any)
            
            guard let first = results.first else { return }
            let position = SIMD3<Float>(first.worldTransform.columns.3.x,
                                        first.worldTransform.columns.3.y,
                                        first.worldTransform.columns.3.z)
            
            if startAnchor == nil {
                // Place start point
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05),
                                         materials: [SimpleMaterial(color: .green, isMetallic: false)])
                let anchor = AnchorEntity(world: position)
                anchor.addChild(sphere)
                view.scene.addAnchor(anchor)
                startAnchor = anchor
                DispatchQueue.main.async {
                    self.parent.distanceText = "Tap to add second point"
                }
            } else {
                // Place end point and measure
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05),
                                         materials: [SimpleMaterial(color: .red, isMetallic: false)])
                let anchor = AnchorEntity(world: position)
                anchor.addChild(sphere)
                view.scene.addAnchor(anchor)
                
                // Calculate distance
                let startPos = startAnchor!.position(relativeTo: nil)
                let endPos = position
                let dist = simd_distance(startPos, endPos)
                let inches = dist * 39.3701
                
                DispatchQueue.main.async {
                    self.parent.distanceText = String(format: "%.2f inches", inches)
                }
                // Reset for next measurement
                startAnchor = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
//        self.arViewRef = arView
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        
        // Add tap gesture recognizer
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(context.coordinator.didTap(_:)))
        arView.addGestureRecognizer(tap)
      //  runSession(on:arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if scenePhase == .background{
            context.coordinator.resetMeasurement(on: uiView)
            runSession(on: uiView)
        }
    }
    
    private func runSession(on arView: ARView) {
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        DispatchQueue.main.async {
        self.distanceText = "Tap two points"
        }
    }
}

private extension ARRulerView.Coordinator {
    @objc func didTap(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view as? ARView else { return }
        let location = sender.location(in: view)
        handleTap(on: view, at: location)
    }
}

