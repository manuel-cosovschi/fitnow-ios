import AVFoundation
import Vision
import Combine

// MARK: - Form analysis result

struct FormCheckResult {
    let score: Int            // 0–100
    let feedback: String
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
}

// MARK: - Supported exercises

enum FormExercise: String, CaseIterable, Identifiable {
    case squat     = "Sentadilla"
    case pushUp    = "Flexión"
    case plank     = "Plancha"
    case deadlift  = "Peso muerto"

    var id: String { rawValue }
    var sfSymbol: String {
        switch self {
        case .squat:    return "figure.strengthtraining.traditional"
        case .pushUp:   return "figure.highintensity.intervaltraining"
        case .plank:    return "figure.core.training"
        case .deadlift: return "figure.strengthtraining.functional"
        }
    }
}

// MARK: - FormCheckService

@MainActor
final class FormCheckService: ObservableObject {
    @Published private(set) var result: FormCheckResult?
    @Published private(set) var isAnalyzing = false

    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    var currentExercise: FormExercise = .squat

    // MARK: - Analyse a single pixel buffer

    func analyse(pixelBuffer: CVPixelBuffer) {
        isAnalyzing = true
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try handler.perform([self.bodyPoseRequest])
                if let obs = self.bodyPoseRequest.results?.first {
                    let result = await self.score(observation: obs, exercise: self.currentExercise)
                    await MainActor.run {
                        self.result = result
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run { self.isAnalyzing = false }
            }
        }
    }

    // MARK: - Scoring per exercise

    private func score(observation: VNHumanBodyPoseObservation, exercise: FormExercise) -> FormCheckResult {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for name in VNHumanBodyPoseObservation.JointName.allNames {
            if let point = try? observation.recognizedPoint(name), point.confidence > 0.3 {
                joints[name] = CGPoint(x: point.x, y: 1 - point.y)
            }
        }

        switch exercise {
        case .squat:    return scoreSquat(joints: joints)
        case .pushUp:   return scorePushUp(joints: joints)
        case .plank:    return scorePlank(joints: joints)
        case .deadlift: return scoreDeadlift(joints: joints)
        }
    }

    // MARK: Squat — checks knee angle + back straightness

    private func scoreSquat(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FormCheckResult {
        guard let leftHip   = joints[.leftHip],
              let leftKnee  = joints[.leftKnee],
              let leftAnkle = joints[.leftAnkle] else {
            return FormCheckResult(score: 0, feedback: "No se detecta la posición completa.", joints: joints)
        }

        let kneeAngle = angle(a: leftHip, b: leftKnee, c: leftAnkle)
        var score = 100
        var feedback = "¡Buena sentadilla!"

        if kneeAngle > 100 {
            score -= 30
            feedback = "Bajá más — el ángulo de rodilla debería ser ≤ 90°."
        } else if kneeAngle < 60 {
            score -= 15
            feedback = "Muy profundo — cuidado con las rodillas."
        }

        if let leftShoulder = joints[.leftShoulder], let leftHipPt = joints[.leftHip] {
            let torsoAngle = angle(a: CGPoint(x: leftShoulder.x, y: 0),
                                   b: leftShoulder,
                                   c: leftHipPt)
            if torsoAngle < 70 {
                score -= 20
                feedback = "Mantenné la espalda más erguida."
            }
        }

        return FormCheckResult(score: max(0, score), feedback: feedback, joints: joints)
    }

    // MARK: Push-up — checks elbow angle + body alignment

    private func scorePushUp(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FormCheckResult {
        guard let leftShoulder = joints[.leftShoulder],
              let leftElbow    = joints[.leftElbow],
              let leftWrist    = joints[.leftWrist] else {
            return FormCheckResult(score: 0, feedback: "No se detecta la posición.", joints: joints)
        }

        let elbowAngle = angle(a: leftShoulder, b: leftElbow, c: leftWrist)
        var score = 100
        var feedback = "¡Buena flexión!"

        if elbowAngle > 100 { score -= 25; feedback = "Bajá el pecho más cerca del suelo." }
        else if elbowAngle < 50 { score -= 10; feedback = "Cuidado — no vayas demasiado abajo." }

        return FormCheckResult(score: max(0, score), feedback: feedback, joints: joints)
    }

    // MARK: Plank — checks hip height vs shoulder line

    private func scorePlank(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FormCheckResult {
        guard let leftShoulder = joints[.leftShoulder],
              let leftHip      = joints[.leftHip],
              let leftAnkle    = joints[.leftAnkle] else {
            return FormCheckResult(score: 0, feedback: "No se detecta la posición.", joints: joints)
        }

        let expectedHipY = leftShoulder.y + (leftAnkle.y - leftShoulder.y) * 0.5
        let deviation = abs(leftHip.y - expectedHipY)
        var score = 100
        var feedback = "¡Plancha perfecta!"

        if deviation > 0.06 {
            score -= Int(deviation * 400)
            feedback = leftHip.y > expectedHipY
                ? "Levantá las caderas — están muy bajas."
                : "Bajá las caderas — están muy altas."
        }

        return FormCheckResult(score: max(0, score), feedback: feedback, joints: joints)
    }

    // MARK: Deadlift — checks back angle during lift

    private func scoreDeadlift(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> FormCheckResult {
        guard let leftShoulder = joints[.leftShoulder],
              let leftHip      = joints[.leftHip],
              let leftKnee     = joints[.leftKnee] else {
            return FormCheckResult(score: 0, feedback: "No se detecta la posición.", joints: joints)
        }

        let backAngle = angle(a: leftShoulder, b: leftHip, c: leftKnee)
        var score = 100
        var feedback = "¡Buena técnica de peso muerto!"

        if backAngle < 140 {
            score -= 30
            feedback = "Mantenné la espalda más recta — riesgo de lesión."
        }

        return FormCheckResult(score: max(0, score), feedback: feedback, joints: joints)
    }

    // MARK: - Geometry helper

    private func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let cb = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = ab.x * cb.x + ab.y * cb.y
        let cross = ab.x * cb.y - ab.y * cb.x
        return abs(atan2(cross, dot) * 180 / .pi)
    }
}

// MARK: - Joint name enumeration helper

extension VNHumanBodyPoseObservation.JointName {
    static var allNames: [VNHumanBodyPoseObservation.JointName] {
        [.nose, .leftEye, .rightEye, .leftEar, .rightEar,
         .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
         .leftWrist, .rightWrist, .leftHip, .rightHip,
         .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .root, .neck]
    }
}
