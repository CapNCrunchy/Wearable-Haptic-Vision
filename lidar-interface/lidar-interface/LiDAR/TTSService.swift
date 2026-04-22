//
//  TTSService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/26/26.
//

import AVFoundation

class TTSService {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for TTS: \(error)")
        }
    }
    
    func speak(_ text: String, rate: Float = 0.5, interrupting: Bool = false) {
        if interrupting && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - Convenience methods for common feedback
    
    func announceSessionStarted() {
        speak("Session started", rate: 0.55)
    }
    
    func announceSessionStopped() {
        speak("Session stopped", rate: 0.55)
    }
    
    func announceDeviceConnecting(name: String) {
        speak("Connecting to \(name)", rate: 0.55)
    }
    
    func announceDeviceConnected(name: String) {
        speak("\(name) connected", rate: 0.55)
    }
    
    func announceDeviceDisconnected() {
        speak("Device disconnected", rate: 0.55)
    }
    
    func announceCollectionStoppedByDisconnection() {
        speak("LiDAR collection stopped due to device disconnection", rate: 0.55)
    }
}
