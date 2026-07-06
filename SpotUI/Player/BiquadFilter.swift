import Foundation

/// Biquad audio filter for DJ-style crossfade transitions.
/// Port of BiquadFilter.kt — direct DSP implementation.
final class BiquadFilter {

    enum FilterType {
        case lowPass, highPass, bandPass, notch
    }

    private var a0: Double = 1
    private var a1: Double = 0
    private var a2: Double = 0
    private var b1: Double = 0
    private var b2: Double = 0

    private var prevX1: Double = 0
    private var prevX2: Double = 0
    private var prevY1: Double = 0
    private var prevY2: Double = 0

    func updateCoefficients(cutoffHz: Double, sampleRate: Double, type: FilterType) {
        let nyquist = sampleRate / 2.0
        let normalizedCutoff = cutoffHz / nyquist
        let clampedCutoff = max(0.001, min(normalizedCutoff, 0.999))
        let omega = 2.0 * .pi * clampedCutoff
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0 * sqrt(2.0) // Q = 1/sqrt(2) for Butterworth

        switch type {
        case .lowPass:
            let norm = 1.0 / (1.0 + alpha)
            a0 = (1.0 - cosOmega) / 2.0 * norm
            a1 = (1.0 - cosOmega) * norm
            a2 = a0
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        case .highPass:
            let norm = 1.0 / (1.0 + alpha)
            a0 = (1.0 + cosOmega) / 2.0 * norm
            a1 = -(1.0 + cosOmega) * norm
            a2 = a0
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        case .bandPass:
            let norm = 1.0 / (1.0 + alpha)
            a0 = alpha * norm
            a1 = 0
            a2 = -alpha * norm
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        case .notch:
            let norm = 1.0 / (1.0 + alpha)
            a0 = norm
            a1 = -2.0 * cosOmega * norm
            a2 = norm
            b1 = -2.0 * cosOmega * norm
            b2 = (1.0 - alpha) * norm
        }
    }

    func processSampleMono(_ input: Double) -> Double {
        let output = a0 * input + a1 * prevX1 + a2 * prevX2 - b1 * prevY1 - b2 * prevY2
        prevX2 = prevX1
        prevX1 = input
        prevY2 = prevY1
        prevY1 = output
        return output
    }

    func processStereo(_ left: Double, _ right: Double) -> (Double, Double) {
        let outL = processSampleMono(left)
        let outR = processSampleMono(right)
        return (outL, outR)
    }

    func reset() {
        prevX1 = 0; prevX2 = 0; prevY1 = 0; prevY2 = 0
    }
}
