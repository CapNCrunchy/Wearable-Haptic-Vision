//
//  TTSService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/26/26.
//

import AVFoundation

/// A service that provides text-to-speech audio feedback throughout the app
class TTSService {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        // Configure audio session for TTS
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
    
    /// Speaks the given text using text-to-speech
    /// - Parameters:
    ///   - text: The text to speak
    ///   - rate: The speech rate (0.0 - 1.0). Default is 0.5
    ///   - interrupting: Whether to stop current speech before starting. Default is false
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
    
    /// Stops any currently playing speech
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
}
