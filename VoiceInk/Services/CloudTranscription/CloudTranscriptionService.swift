import Foundation
import os

enum CloudTranscriptionError: Error, LocalizedError {
    case unsupportedProvider
    case missingAPIKey
    case invalidAPIKey
    case audioFileNotFound
    case apiRequestFailed(statusCode: Int, message: String)
    case networkError(Error)
    case noTranscriptionReturned
    case dataEncodingError
    
    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return "The model provider is not supported by this service."
        case .missingAPIKey:
            return "API key for this service is missing. Please configure it in the settings."
        case .invalidAPIKey:
            return "The provided API key is invalid."
        case .audioFileNotFound:
            return "The audio file to transcribe could not be found."
        case .apiRequestFailed(let statusCode, let message):
            return "The API request failed with status code \(statusCode): \(message)"
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .noTranscriptionReturned:
            return "The API returned an empty or invalid response."
        case .dataEncodingError:
            return "Failed to encode the request body."
        }
    }
}

class CloudTranscriptionService: TranscriptionService {
    
    private lazy var groqService = GroqTranscriptionService()
    private lazy var elevenLabsService = ElevenLabsTranscriptionService()
    private lazy var deepgramService = DeepgramTranscriptionService()
    private lazy var mistralService = MistralTranscriptionService()
    private lazy var geminiService = GeminiTranscriptionService()
    private lazy var openAICompatibleService = OpenAICompatibleTranscriptionService()
    private lazy var sonioxService = SonioxTranscriptionService()
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        let providerKey = providerKeyString(for: model.provider)
        let keyManager = CloudAPIKeyManager.shared
        
        if usesManagedAPIKeys(for: model.provider) && !keyManager.hasKeys(for: providerKey) {
            throw CloudTranscriptionError.missingAPIKey
        }
        
        var triedKeyIds = Set<UUID>()
        var lastError: Error?
        
        while true {
            if usesManagedAPIKeys(for: model.provider) {
                guard let currentKey = keyManager.activeKey(for: providerKey) else {
                    throw lastError ?? CloudTranscriptionError.missingAPIKey
                }
                
                if triedKeyIds.contains(currentKey.id) {
                    // All keys have been tried in this session
                    throw lastError ?? CloudTranscriptionError.invalidAPIKey
                }
                
                triedKeyIds.insert(currentKey.id)
                keyManager.markCurrentKeyUsed(for: providerKey)
            }
            
            do {
                let text = try await transcribeOnce(audioURL: audioURL, model: model)
                return text
            } catch let error as CloudTranscriptionError {
                lastError = error
                
                switch error {
                case .apiRequestFailed(let statusCode, _):
                    if statusCode == 401 || statusCode == 403 || statusCode == 429 {
                        if usesManagedAPIKeys(for: model.provider),
                           keyManager.rotateKey(for: providerKey) {
                            continue
                        }
                    }
                    throw error
                case .missingAPIKey, .invalidAPIKey:
                    if usesManagedAPIKeys(for: model.provider),
                       keyManager.rotateKey(for: providerKey) {
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }
    }

    private func transcribeOnce(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        switch model.provider {
        case .groq:
            return try await groqService.transcribe(audioURL: audioURL, model: model)
        case .elevenLabs:
            return try await elevenLabsService.transcribe(audioURL: audioURL, model: model)
        case .deepgram:
            return try await deepgramService.transcribe(audioURL: audioURL, model: model)
        case .mistral:
            return try await mistralService.transcribe(audioURL: audioURL, model: model)
        case .gemini:
            return try await geminiService.transcribe(audioURL: audioURL, model: model)
        case .soniox:
            return try await sonioxService.transcribe(audioURL: audioURL, model: model)
        case .custom:
            guard let customModel = model as? CustomCloudModel else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            return try await openAICompatibleService.transcribe(audioURL: audioURL, model: customModel)
        default:
            throw CloudTranscriptionError.unsupportedProvider
        }
    }
    
    private func providerKeyString(for provider: ModelProvider) -> String {
        switch provider {
        case .groq:
            return "GROQ"
        case .elevenLabs:
            return "ElevenLabs"
        case .deepgram:
            return "Deepgram"
        case .mistral:
            return "Mistral"
        case .gemini:
            return "Gemini"
        case .soniox:
            return "Soniox"
        default:
            return provider.rawValue
        }
    }
    
    private func usesManagedAPIKeys(for provider: ModelProvider) -> Bool {
        switch provider {
        case .groq, .elevenLabs, .deepgram, .mistral, .gemini, .soniox:
            return true
        default:
            return false
        }
    }
} 
