//
//  ARCoordinator.swift
//  ARRealityKitTest
//
//  Created by Aynur Nasybullin on 02.11.2024.
//

import RealityKit
import Combine
import Foundation

enum Joint {
    case head
    case leftEye
    case rightEye

    var name: String {
        switch self {
            case .head:
                "root_mob/pelvis_mob/spine01_mob/spine02_mob/spine03_mob/spine04_mob/spine05_mob/neck01_mob/neck02_mob/head01_mob"
            case .leftEye:
                "root_mob/pelvis_mob/spine01_mob/spine02_mob/spine03_mob/spine04_mob/spine05_mob/neck01_mob/neck02_mob/head01_mob/FACIAL_C_FacialRoot_mob/FACIAL_L_Eye_mob"
            case .rightEye:
                "root_mob/pelvis_mob/spine01_mob/spine02_mob/spine03_mob/spine04_mob/spine05_mob/neck01_mob/neck02_mob/head01_mob/FACIAL_C_FacialRoot_mob/FACIAL_R_Eye_mob"
        }
    }

    var suffix: String {
        switch self {
            case .head:     "/head01_mob"
            case .leftEye:  "FACIAL_L_Eye_mob"
            case .rightEye: "FACIAL_R_Eye_mob"
        }
    }
}

final class ARCoordinator {
    var entityAnchor: AnchorEntity?
    var modelEntity: ModelEntity = ModelEntity()
    var entity: Entity?
    
    var head: Entity?
    var leftEye: Entity?
    var rightEye: Entity?

    var headJointIdx = 0
    var rightEyeJointIdx = 0
    var leftEyeJointIdx = 0
    
    var animationsIsFinished = false
    var skeletoneIsBuilded = false
    var entities = [String: Entity]()
    
    var playbackController: AnimationPlaybackController?

    var cancellables = Set<AnyCancellable>()
}

extension ARCoordinator {
    func loadModelEntityToARView(arView: ARView, modelEntity: ModelEntity) {
        let anchorEntity = AnchorEntity(.plane(
            .horizontal,
            classification: .any,
            minimumBounds: SIMD2<Float>(0.2, 0.2))
        )
    
        anchorEntity.scale = [1, 1, 1]
        anchorEntity.addChild(modelEntity)
        arView.scene.addAnchor(anchorEntity)
        
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .red, isMetallic: true)]
        )
        anchorEntity.addChild(sphere)
            
        self.entityAnchor = anchorEntity
        self.modelEntity = modelEntity
        
        print(modelEntity)
        
        if let idx = modelEntity.jointNames.firstIndex(where: { $0.hasSuffix(Joint.head.suffix) }),
           let idxL = modelEntity.jointNames.firstIndex(where: { $0.hasSuffix(Joint.leftEye.suffix) }),
           let idxR = modelEntity.jointNames.firstIndex(where: { $0.hasSuffix(Joint.rightEye.suffix) }) {
           
            self.headJointIdx = idx
            self.leftEyeJointIdx = idxL
            self.rightEyeJointIdx = idxR
        }
        
        Task.detached { [weak self] in
            let entity = await self?.buildGraphAsync(
                jointNames: modelEntity.jointNames,
                jointTransforms: modelEntity.jointTransforms
            )
            
            await MainActor.run { [weak self] in
                if let skeletoneEntity = entity {
                    anchorEntity.addChild(skeletoneEntity)
                }
                self?.entity = entity
            }
        }
        
        arView.scene
            .subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                guard let self, self.skeletoneIsBuilded else { return }
                
                look(
                    atPosition: arView.cameraTransform.translation,
                    transformId: headJointIdx
                )
                
                lookWithBothEyes(
                    atPosition: arView.cameraTransform.translation,
                    leftEyeTransformId: leftEyeJointIdx,
                    rightEyeTransformId: rightEyeJointIdx,
                    forwardVector: [0, 1, 1]
                )
            }
            .store(in: &cancellables)
        
        playbackController = modelEntity.playAnimation(
            try! AnimationResource.sequence(with: modelEntity.availableAnimations).repeat(count: 1)
        )
            
        DispatchQueue.main.async {
            self.checkAnimationCompletion()
        }
    }
    
    func checkAnimationCompletion() {
        guard let playbackController = playbackController else {
            return animationsIsFinished = true
        }

        if playbackController.isPlaying == false {
            print("Animation is finished!")
            animationsIsFinished = true
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkAnimationCompletion()
            }
        }
    }

    private func look(
        atPosition: SIMD3<Float>,
        maxRotationRadians: Float = .pi / 4,
        transformId: Int,
        forwardVector: SIMD3<Float> = [0, 1, 1]
    ) {
        let transform = modelEntity.jointTransforms[transformId]
        let position = modelEntity.convert(position: transform.translation, to: nil)
        
        let directionToCamera = normalize(atPosition - position)
        let rotationToCamera = simd_quatf(from: forwardVector, to: directionToCamera)
        
        var eulerAngles = rotationToCamera.eulerAngles
        eulerAngles.x = clamp(eulerAngles.x, min: -maxRotationRadians, max: maxRotationRadians)
        eulerAngles.y = clamp(eulerAngles.y, min: -maxRotationRadians, max: maxRotationRadians)
        eulerAngles.z = clamp(eulerAngles.z, min: -maxRotationRadians, max: maxRotationRadians)

        let limitedRotation = eulerAngles.quaternion
        modelEntity.jointTransforms[transformId].rotation = limitedRotation
    }
    
    private func lookWithBothEyes(
        atPosition: SIMD3<Float>,
        maxRotationRadians: Float = .pi / 8,
        leftEyeTransformId: Int,
        rightEyeTransformId: Int,
        forwardVector: SIMD3<Float> = [0, 1, 1]
    ) {
        let leftEyePosition = modelEntity.convert(
            position: modelEntity.jointTransforms[leftEyeTransformId].translation,
            to: nil
        )
        let rightEyePosition = modelEntity.convert(
            position: modelEntity.jointTransforms[rightEyeTransformId].translation, 
            to: nil
        )
        
        let leftDirectionToTarget = normalize(atPosition - leftEyePosition)
        let rightDirectionToTarget = normalize(atPosition - rightEyePosition)

        let averageDirectionToTarget = normalize((leftDirectionToTarget + rightDirectionToTarget) / 2.0)
        let rotationToTarget = simd_quatf(from: forwardVector, to: averageDirectionToTarget)
        
        var eulerAngles = rotationToTarget.eulerAngles
        eulerAngles.x = clamp(eulerAngles.x, min: -maxRotationRadians, max: maxRotationRadians)
        eulerAngles.y = clamp(eulerAngles.y, min: -maxRotationRadians, max: maxRotationRadians)
        eulerAngles.z = clamp(eulerAngles.z, min: -maxRotationRadians, max: maxRotationRadians)
        
        let limitedRotation = eulerAngles.quaternion
        modelEntity.jointTransforms[leftEyeTransformId].rotation = limitedRotation
        modelEntity.jointTransforms[rightEyeTransformId].rotation = limitedRotation
    }
}


extension ARCoordinator {
    func buildGraphAsync(jointNames: [String], jointTransforms: [Transform]) async -> Entity? {
        let graphRoot = await withTaskGroup(of: Entity?.self) { group in
            group.addTask { [weak self] in
                return self?.buildGraph(jointNames: jointNames, jointTransforms: jointTransforms)
            }
            
            return await group.first(where: { $0 != nil }) ?? nil
        }
        skeletoneIsBuilded = true
        
        return graphRoot
    }
    
    private func buildGraph(jointNames: [String], jointTransforms: [Transform]) -> Entity? {
        guard jointNames.count == jointTransforms.count else {
            print("Error: the number of names and transformations does not match.")
            return nil
        }

        var idx = 0
        let root = Entity.create(name: jointNames[idx], transform: jointTransforms[idx])
        entities = [jointNames[idx]: root]
        idx += 1

        while idx < jointNames.count {
            let name = jointNames[idx]
            let transform = jointTransforms[idx]
            
            let parentPathComponents = name.split(separator: "/").dropLast()
            let parentName = parentPathComponents.joined(separator: "/")

            let entity = Entity.create(name: name, transform: transform)
            entities[name] = entity

            if let parent = entities[parentName] {
                parent.addChild(entity)
            } else {
                print("Parent not fount for: \(name)")
            }
            
            idx += 1
        }
        
        return root
    }
}
