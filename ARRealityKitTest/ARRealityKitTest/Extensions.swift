//
//  Extensions.swift
//  ARRealityKitTest
//
//  Created by Aynur Nasybullin on 02.11.2024.
//

import Foundation
import RealityKit

func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
    return max(min(value, maxValue), minValue)
}


extension Entity {
    static func create(name: String, transform: Transform) -> Entity {
        let entity = Entity()
        entity.name = name
        entity.transform = transform
        
        return entity
    }
}


extension SIMD3<Float> {
    // Функция для преобразования углов Эйлера (в радианах) в кватернион
    var quaternion: simd_quatf {
        let pitch = x
        let yaw = y
        let roll = z

        // Создаем кватернионы для каждого вращения вокруг осей
        let qx = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0)) // Вращение вокруг X
        let qy = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))   // Вращение вокруг Y
        let qz = simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1))  // Вращение вокруг Z

        // Комбинируем вращения: сначала Z, затем Y, затем X (обычный порядок для систем XYZ)
        return qz * qy * qx
    }
}


extension simd_quatf {
    // Функция для преобразования кватерниона в углы Эйлера (в радианах)
    var eulerAngles: SIMD3<Float> {
        let q = vector

        // Вычисление углов Эйлера по каждой оси (в радианах)
        let pitch = atan2(2 * (q.w * q.x + q.y * q.z), 1 - 2 * (q.x * q.x + q.y * q.y))
        let yaw = asin(2 * (q.w * q.y - q.z * q.x))
        let roll = atan2(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.y * q.y + q.z * q.z))

        return SIMD3<Float>(pitch, yaw, roll)  // Порядок: (x, y, z)
    }
}
