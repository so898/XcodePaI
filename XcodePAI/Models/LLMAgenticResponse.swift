//
//  LLMAgenticResponse.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2026/2/7.
//

import Foundation

enum LLMAgenticResponseEvent: Codable {
    case responseCreated(ResponseCreatedEvent)
    case responseInProgress(ResponseInProgressEvent)
    case responseCompleted(ResponseCompletedEvent)
    case responseFailed(ResponseFailedEvent)
    case responseIncomplete(ResponseIncompleteEvent)
    case responseQueued(ResponseQueuedEvent)
    
    case outputItemAdded(OutputItemAddedEvent)
    case outputItemDone(OutputItemDoneEvent)
    
    case contentPartAdded(ContentPartAddedEvent)
    case contentPartDone(ContentPartDoneEvent)
    
    case outputTextDelta(OutputTextDeltaEvent)
    case outputTextDone(OutputTextDoneEvent)
    case outputTextAnnotationAdded(OutputTextAnnotationAddedEvent)
    
    case refusalDelta(RefusalDeltaEvent)
    case refusalDone(RefusalDoneEvent)
    
    case functionCallArgumentsDelta(FunctionCallArgumentsDeltaEvent)
    case functionCallArgumentsDone(FunctionCallArgumentsDoneEvent)
    
    case fileSearchCallInProgress(FileSearchCallInProgressEvent)
    case fileSearchCallSearching(FileSearchCallSearchingEvent)
    case fileSearchCallCompleted(FileSearchCallCompletedEvent)
    
    case webSearchCallInProgress(WebSearchCallInProgressEvent)
    case webSearchCallSearching(WebSearchCallSearchingEvent)
    case webSearchCallCompleted(WebSearchCallCompletedEvent)
    
    case reasoningSummaryPartAdded(ReasoningSummaryPartAddedEvent)
    case reasoningSummaryPartDone(ReasoningSummaryPartDoneEvent)
    case reasoningSummaryTextDelta(ReasoningSummaryTextDeltaEvent)
    case reasoningSummaryTextDone(ReasoningSummaryTextDoneEvent)
    
    case reasoningTextDelta(ReasoningTextDeltaEvent)
    case reasoningTextDone(ReasoningTextDoneEvent)
    
    case imageGenerationCallInProgress(ImageGenerationCallInProgressEvent)
    case imageGenerationCallGenerating(ImageGenerationCallGeneratingEvent)
    case imageGenerationCallCompleted(ImageGenerationCallCompletedEvent)
    case imageGenerationCallPartialImage(ImageGenerationCallPartialImageEvent)
    
    case mcpCallInProgress(MCPCallInProgressEvent)
    case mcpCallCompleted(MCPCallCompletedEvent)
    case mcpCallFailed(MCPCallFailedEvent)
    case mcpCallArgumentsDelta(MCPCallArgumentsDeltaEvent)
    case mcpCallArgumentsDone(MCPCallArgumentsDoneEvent)
    
    case mcpListToolsInProgress(MCPListToolsInProgressEvent)
    case mcpListToolsCompleted(MCPListToolsCompletedEvent)
    case mcpListToolsFailed(MCPListToolsFailedEvent)
    
    case codeInterpreterCallInProgress(CodeInterpreterCallInProgressEvent)
    case codeInterpreterCallInterpreting(CodeInterpreterCallInterpretingEvent)
    case codeInterpreterCallCompleted(CodeInterpreterCallCompletedEvent)
    case codeInterpreterCallCodeDelta(CodeInterpreterCallCodeDeltaEvent)
    case codeInterpreterCallCodeDone(CodeInterpreterCallCodeDoneEvent)
    
    case customToolCallInputDelta(CustomToolCallInputDeltaEvent)
    case customToolCallInputDone(CustomToolCallInputDoneEvent)
    
    case error(ErrorEvent)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "response.created":
            self = .responseCreated(try ResponseCreatedEvent(from: decoder))
        case "response.in_progress":
            self = .responseInProgress(try ResponseInProgressEvent(from: decoder))
        case "response.completed":
            self = .responseCompleted(try ResponseCompletedEvent(from: decoder))
        case "response.failed":
            self = .responseFailed(try ResponseFailedEvent(from: decoder))
        case "response.incomplete":
            self = .responseIncomplete(try ResponseIncompleteEvent(from: decoder))
        case "response.queued":
            self = .responseQueued(try ResponseQueuedEvent(from: decoder))
        case "response.output_item.added":
            self = .outputItemAdded(try OutputItemAddedEvent(from: decoder))
        case "response.output_item.done":
            self = .outputItemDone(try OutputItemDoneEvent(from: decoder))
        case "response.content_part.added":
            self = .contentPartAdded(try ContentPartAddedEvent(from: decoder))
        case "response.content_part.done":
            self = .contentPartDone(try ContentPartDoneEvent(from: decoder))
        case "response.output_text.delta":
            self = .outputTextDelta(try OutputTextDeltaEvent(from: decoder))
        case "response.output_text.done":
            self = .outputTextDone(try OutputTextDoneEvent(from: decoder))
        case "response.output_text.annotation.added":
            self = .outputTextAnnotationAdded(try OutputTextAnnotationAddedEvent(from: decoder))
        case "response.refusal.delta":
            self = .refusalDelta(try RefusalDeltaEvent(from: decoder))
        case "response.refusal.done":
            self = .refusalDone(try RefusalDoneEvent(from: decoder))
        case "response.function_call_arguments.delta":
            self = .functionCallArgumentsDelta(try FunctionCallArgumentsDeltaEvent(from: decoder))
        case "response.function_call_arguments.done":
            self = .functionCallArgumentsDone(try FunctionCallArgumentsDoneEvent(from: decoder))
        case "response.file_search_call.in_progress":
            self = .fileSearchCallInProgress(try FileSearchCallInProgressEvent(from: decoder))
        case "response.file_search_call.searching":
            self = .fileSearchCallSearching(try FileSearchCallSearchingEvent(from: decoder))
        case "response.file_search_call.completed":
            self = .fileSearchCallCompleted(try FileSearchCallCompletedEvent(from: decoder))
        case "response.web_search_call.in_progress":
            self = .webSearchCallInProgress(try WebSearchCallInProgressEvent(from: decoder))
        case "response.web_search_call.searching":
            self = .webSearchCallSearching(try WebSearchCallSearchingEvent(from: decoder))
        case "response.web_search_call.completed":
            self = .webSearchCallCompleted(try WebSearchCallCompletedEvent(from: decoder))
        case "response.reasoning_summary_part.added":
            self = .reasoningSummaryPartAdded(try ReasoningSummaryPartAddedEvent(from: decoder))
        case "response.reasoning_summary_part.done":
            self = .reasoningSummaryPartDone(try ReasoningSummaryPartDoneEvent(from: decoder))
        case "response.reasoning_summary_text.delta":
            self = .reasoningSummaryTextDelta(try ReasoningSummaryTextDeltaEvent(from: decoder))
        case "response.reasoning_summary_text.done":
            self = .reasoningSummaryTextDone(try ReasoningSummaryTextDoneEvent(from: decoder))
        case "response.reasoning_text.delta":
            self = .reasoningTextDelta(try ReasoningTextDeltaEvent(from: decoder))
        case "response.reasoning_text.done":
            self = .reasoningTextDone(try ReasoningTextDoneEvent(from: decoder))
        case "response.image_generation_call.in_progress":
            self = .imageGenerationCallInProgress(try ImageGenerationCallInProgressEvent(from: decoder))
        case "response.image_generation_call.generating":
            self = .imageGenerationCallGenerating(try ImageGenerationCallGeneratingEvent(from: decoder))
        case "response.image_generation_call.completed":
            self = .imageGenerationCallCompleted(try ImageGenerationCallCompletedEvent(from: decoder))
        case "response.image_generation_call.partial_image":
            self = .imageGenerationCallPartialImage(try ImageGenerationCallPartialImageEvent(from: decoder))
        case "response.mcp_call.in_progress":
            self = .mcpCallInProgress(try MCPCallInProgressEvent(from: decoder))
        case "response.mcp_call.completed":
            self = .mcpCallCompleted(try MCPCallCompletedEvent(from: decoder))
        case "response.mcp_call.failed":
            self = .mcpCallFailed(try MCPCallFailedEvent(from: decoder))
        case "response.mcp_call_arguments.delta":
            self = .mcpCallArgumentsDelta(try MCPCallArgumentsDeltaEvent(from: decoder))
        case "response.mcp_call_arguments.done":
            self = .mcpCallArgumentsDone(try MCPCallArgumentsDoneEvent(from: decoder))
        case "response.mcp_list_tools.in_progress":
            self = .mcpListToolsInProgress(try MCPListToolsInProgressEvent(from: decoder))
        case "response.mcp_list_tools.completed":
            self = .mcpListToolsCompleted(try MCPListToolsCompletedEvent(from: decoder))
        case "response.mcp_list_tools.failed":
            self = .mcpListToolsFailed(try MCPListToolsFailedEvent(from: decoder))
        case "response.code_interpreter_call.in_progress":
            self = .codeInterpreterCallInProgress(try CodeInterpreterCallInProgressEvent(from: decoder))
        case "response.code_interpreter_call.interpreting":
            self = .codeInterpreterCallInterpreting(try CodeInterpreterCallInterpretingEvent(from: decoder))
        case "response.code_interpreter_call.completed":
            self = .codeInterpreterCallCompleted(try CodeInterpreterCallCompletedEvent(from: decoder))
        case "response.code_interpreter_call_code.delta":
            self = .codeInterpreterCallCodeDelta(try CodeInterpreterCallCodeDeltaEvent(from: decoder))
        case "response.code_interpreter_call_code.done":
            self = .codeInterpreterCallCodeDone(try CodeInterpreterCallCodeDoneEvent(from: decoder))
        case "response.custom_tool_call_input.delta":
            self = .customToolCallInputDelta(try CustomToolCallInputDeltaEvent(from: decoder))
        case "response.custom_tool_call_input.done":
            self = .customToolCallInputDone(try CustomToolCallInputDoneEvent(from: decoder))
        case "error":
            self = .error(try ErrorEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .responseCreated(let event):
            try event.encode(to: encoder)
        case .responseInProgress(let event):
            try event.encode(to: encoder)
        case .responseCompleted(let event):
            try event.encode(to: encoder)
        case .responseFailed(let event):
            try event.encode(to: encoder)
        case .responseIncomplete(let event):
            try event.encode(to: encoder)
        case .responseQueued(let event):
            try event.encode(to: encoder)
        case .outputItemAdded(let event):
            try event.encode(to: encoder)
        case .outputItemDone(let event):
            try event.encode(to: encoder)
        case .contentPartAdded(let event):
            try event.encode(to: encoder)
        case .contentPartDone(let event):
            try event.encode(to: encoder)
        case .outputTextDelta(let event):
            try event.encode(to: encoder)
        case .outputTextDone(let event):
            try event.encode(to: encoder)
        case .outputTextAnnotationAdded(let event):
            try event.encode(to: encoder)
        case .refusalDelta(let event):
            try event.encode(to: encoder)
        case .refusalDone(let event):
            try event.encode(to: encoder)
        case .functionCallArgumentsDelta(let event):
            try event.encode(to: encoder)
        case .functionCallArgumentsDone(let event):
            try event.encode(to: encoder)
        case .fileSearchCallInProgress(let event):
            try event.encode(to: encoder)
        case .fileSearchCallSearching(let event):
            try event.encode(to: encoder)
        case .fileSearchCallCompleted(let event):
            try event.encode(to: encoder)
        case .webSearchCallInProgress(let event):
            try event.encode(to: encoder)
        case .webSearchCallSearching(let event):
            try event.encode(to: encoder)
        case .webSearchCallCompleted(let event):
            try event.encode(to: encoder)
        case .reasoningSummaryPartAdded(let event):
            try event.encode(to: encoder)
        case .reasoningSummaryPartDone(let event):
            try event.encode(to: encoder)
        case .reasoningSummaryTextDelta(let event):
            try event.encode(to: encoder)
        case .reasoningSummaryTextDone(let event):
            try event.encode(to: encoder)
        case .reasoningTextDelta(let event):
            try event.encode(to: encoder)
        case .reasoningTextDone(let event):
            try event.encode(to: encoder)
        case .imageGenerationCallInProgress(let event):
            try event.encode(to: encoder)
        case .imageGenerationCallGenerating(let event):
            try event.encode(to: encoder)
        case .imageGenerationCallCompleted(let event):
            try event.encode(to: encoder)
        case .imageGenerationCallPartialImage(let event):
            try event.encode(to: encoder)
        case .mcpCallInProgress(let event):
            try event.encode(to: encoder)
        case .mcpCallCompleted(let event):
            try event.encode(to: encoder)
        case .mcpCallFailed(let event):
            try event.encode(to: encoder)
        case .mcpCallArgumentsDelta(let event):
            try event.encode(to: encoder)
        case .mcpCallArgumentsDone(let event):
            try event.encode(to: encoder)
        case .mcpListToolsInProgress(let event):
            try event.encode(to: encoder)
        case .mcpListToolsCompleted(let event):
            try event.encode(to: encoder)
        case .mcpListToolsFailed(let event):
            try event.encode(to: encoder)
        case .codeInterpreterCallInProgress(let event):
            try event.encode(to: encoder)
        case .codeInterpreterCallInterpreting(let event):
            try event.encode(to: encoder)
        case .codeInterpreterCallCompleted(let event):
            try event.encode(to: encoder)
        case .codeInterpreterCallCodeDelta(let event):
            try event.encode(to: encoder)
        case .codeInterpreterCallCodeDone(let event):
            try event.encode(to: encoder)
        case .customToolCallInputDelta(let event):
            try event.encode(to: encoder)
        case .customToolCallInputDone(let event):
            try event.encode(to: encoder)
        case .error(let event):
            try event.encode(to: encoder)
        }
    }
    
    // MARK: - Response
    struct Response: Codable {
        let id: String
        let object: String
        let createdAt: Int
        let status: String // completed, failed, in_progress, cancelled, queued, or incomplete
        let completedAt: Int?
        let error: ResponseError?
        let incompleteDetails: IncompleteDetails?
        let instructions: String?
        let maxOutputTokens: Int?
        let model: String
        let output: [OutputItem]
        let parallelToolCalls: Bool?
        let previousResponseId: String?
        let reasoning: Reasoning?
        let store: Bool?
        let temperature: Double?
        let text: TextFormat?
        let toolChoice: String?
        let tools: [Tool]?
        let topP: Double?
        let truncation: String?
        let usage: Usage?
        let user: String?
        let metadata: [String: String]?
        let input: [String]?
        let reasoningEffort: String?
        
        enum CodingKeys: String, CodingKey {
            case id, object, status, error, instructions, model, output, tools, usage, user, metadata, input, store, truncation
            case createdAt = "created_at"
            case completedAt = "completed_at"
            case incompleteDetails = "incomplete_details"
            case maxOutputTokens = "max_output_tokens"
            case parallelToolCalls = "parallel_tool_calls"
            case previousResponseId = "previous_response_id"
            case reasoning
            case temperature
            case text
            case toolChoice = "tool_choice"
            case topP = "top_p"
            case reasoningEffort = "reasoning_effort"
        }
        
        init(
            id: String,
            object: String = "Response",
            createdAt: Int,
            status: String,
            model: String,
            output: [OutputItem] = [],
            completedAt: Int? = nil,
            error: ResponseError? = nil,
            incompleteDetails: IncompleteDetails? = nil,
            instructions: String? = nil,
            maxOutputTokens: Int? = nil,
            parallelToolCalls: Bool? = nil,
            previousResponseId: String? = nil,
            reasoning: Reasoning? = nil,
            store: Bool? = nil,
            temperature: Double? = nil,
            text: TextFormat? = nil,
            toolChoice: String? = nil,
            tools: [Tool]? = nil,
            topP: Double? = nil,
            truncation: String? = nil,
            usage: Usage? = nil,
            user: String? = nil,
            metadata: [String: String]? = nil,
            input: [String]? = nil,
            reasoningEffort: String? = nil
        ) {
            self.id = id
            self.object = object
            self.createdAt = createdAt
            self.status = status
            self.model = model
            self.output = output
            self.completedAt = completedAt
            self.error = error
            self.incompleteDetails = incompleteDetails
            self.instructions = instructions
            self.maxOutputTokens = maxOutputTokens
            self.parallelToolCalls = parallelToolCalls
            self.previousResponseId = previousResponseId
            self.reasoning = reasoning
            self.store = store
            self.temperature = temperature
            self.text = text
            self.toolChoice = toolChoice
            self.tools = tools
            self.topP = topP
            self.truncation = truncation
            self.usage = usage
            self.user = user
            self.metadata = metadata
            self.input = input
            self.reasoningEffort = reasoningEffort
        }
    }
    
    struct ResponseError: Codable {
        let code: String
        let message: String
    }
    
    struct IncompleteDetails: Codable {
        let reason: String
    }
    
    struct Reasoning: Codable {
        let effort: String?
        let summary: String?
        
        init(effort: String? = nil, summary: String? = nil) {
            self.effort = effort
            self.summary = summary
        }
    }
    
    struct TextFormat: Codable {
        let format: FormatType
        
        struct FormatType: Codable {
            let type: String
        }
    }
    
    struct Tool: Codable {
        //
    }
    
    struct Usage: Codable {
        let inputTokens: Int
        let outputTokens: Int
        let outputTokensDetails: OutputTokensDetails?
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case outputTokensDetails = "output_tokens_details"
            case totalTokens = "total_tokens"
        }
        
        init(
            inputTokens: Int,
            outputTokens: Int,
            totalTokens: Int,
            outputTokensDetails: OutputTokensDetails? = nil
        ) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.totalTokens = totalTokens
            self.outputTokensDetails = outputTokensDetails
        }
    }
    
    struct OutputTokensDetails: Codable {
        let reasoningTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case reasoningTokens = "reasoning_tokens"
        }
    }
    
    // MARK: - Output Item
    enum OutputItem: Codable {
        case message(MessageItem)
        case functionCall(FunctionCallItem)
        case reasoning(ReasoningItem)
        
        enum CodingKeys: String, CodingKey {
            case type
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "message":
                self = .message(try MessageItem(from: decoder))
            case "function_call":
                self = .functionCall(try FunctionCallItem(from: decoder))
            case "reasoing":
                self = .reasoning(try ReasoningItem(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown output item type: \(type)")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .message(let item):
                try item.encode(to: encoder)
            case .functionCall(let item):
                try item.encode(to: encoder)
            case .reasoning(let item):
                try item.encode(to: encoder)
            }
        }
    }
    
    struct MessageItem: Codable {
        let id: String
        let type: String
        let role: String
        let content: [ContentPart]
        let status: String? // in_progress, completed, or incomplete
        
        init(id: String, role: String = "assistant", content: [ContentPart], status: String? = nil) {
            self.id = id
            self.type = "message"
            self.role = role
            self.content = content
            self.status = status
        }
    }
    
    struct FunctionCallItem: Codable {
        let id: String
        let callId: String
        let type: String
        let name: String?
        let arguments: String?
        let status: String?
        
        enum CodingKeys: String, CodingKey {
            case id, type, name, arguments, status
            case callId = "call_id"
        }
        
        init(id: String, callId: String, name: String? = nil, arguments: String? = nil, status: String? = nil) {
            self.id = id
            self.callId = callId
            self.type = "function_call"
            self.name = name
            self.arguments = arguments
            self.status = status
        }
    }
    
    struct ReasoningItem: Codable {
        let id: String
        let type: String
        let summary: [ReasoningSummaryPart]?
        let content: [ReasoningContentPart]?
        let encryptedContent: String?
        let status: String? // in_progress, completed, or incomplete
        
        enum CodingKeys: String, CodingKey {
            case id, type, summary, content, status
            case encryptedContent = "encrypted_content"
        }
        
        init(id: String, summary: [ReasoningSummaryPart]? = nil, content: [ReasoningContentPart]? = nil, encryptedContent: String? = nil, status: String? = nil) {
            self.id = id
            self.type = "reasoning"
            self.summary = summary
            self.content = content
            self.encryptedContent = encryptedContent
            self.status = status
        }
    }
    
    // MARK: - Content Part
    enum ContentPart: Codable {
        case outputText(OutputTextPart)
        case refusal(RefusalPart)
        
        enum CodingKeys: String, CodingKey {
            case type
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "output_text":
                self = .outputText(try OutputTextPart(from: decoder))
            case "refusal":
                self = .refusal(try RefusalPart(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown Type: \(type)")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .outputText(let part):
                try part.encode(to: encoder)
            case .refusal(let part):
                try part.encode(to: encoder)
            }
        }
    }
    
    struct OutputTextPart: Codable {
        let type: String
        let text: String
        let annotations: [Annotation]
        
        init(text: String, annotations: [Annotation] = []) {
            self.type = "output_text"
            self.text = text
            self.annotations = annotations
        }
    }
    
    struct RefusalPart: Codable {
        let type: String
        let refusal: String
        
        init(refusal: String) {
            self.type = "refusal"
            self.refusal = refusal
        }
    }
    
    struct ReasoningSummaryPart: Codable {
        let type: String
        let text: String
        
        init(text: String) {
            self.type = "summary_text"
            self.text = text
        }
    }
    
    struct ReasoningContentPart: Codable {
        let type: String
        let text: String
        
        init(text: String) {
            self.type = "reasoning_text"
            self.text = text
        }
    }
    
    struct Annotation: Codable {
        let type: String
        let text: String?
        let start: Int?
        let end: Int?
        
        init(type: String, text: String? = nil, start: Int? = nil, end: Int? = nil) {
            self.type = type
            self.text = text
            self.start = start
            self.end = end
        }
    }
    
    // MARK: - Summary Part
    struct SummaryPart: Codable {
        let type: String
        let text: String
        
        init(text: String) {
            self.type = "text"
            self.text = text
        }
    }
    
    // MARK: - Log Probabilities
    struct LogProbs: Codable {
        let token: String
        let logprob: Double
        let bytes: [Int]?
        let topLogprobs: [TopLogProb]?
        
        enum CodingKeys: String, CodingKey {
            case token, logprob, bytes
            case topLogprobs = "top_logprobs"
        }
        
        init(token: String, logprob: Double, bytes: [Int]? = nil, topLogprobs: [TopLogProb]? = nil) {
            self.token = token
            self.logprob = logprob
            self.bytes = bytes
            self.topLogprobs = topLogprobs
        }
    }
    
    struct TopLogProb: Codable {
        let token: String
        let logprob: Double
        let bytes: [Int]?
        
        init(token: String, logprob: Double, bytes: [Int]? = nil) {
            self.token = token
            self.logprob = logprob
            self.bytes = bytes
        }
    }
    
    // MARK: - event
    struct ResponseCreatedEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int) {
            self.type = "response.created"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ResponseInProgressEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int) {
            self.type = "response.in_progress"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ResponseCompletedEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int) {
            self.type = "response.completed"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ResponseFailedEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int?
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int? = nil) {
            self.type = "response.failed"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ResponseIncompleteEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int) {
            self.type = "response.incomplete"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ResponseQueuedEvent: Codable {
        let type: String
        let response: Response
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, response
            case sequenceNumber = "sequence_number"
        }
        
        init(response: Response, sequenceNumber: Int) {
            self.type = "response.queued"
            self.response = response
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct OutputItemAddedEvent: Codable {
        let type: String
        let outputIndex: Int
        let item: OutputItem
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, item
            case outputIndex = "output_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, item: OutputItem, sequenceNumber: Int) {
            self.type = "response.output_item.added"
            self.outputIndex = outputIndex
            self.item = item
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct OutputItemDoneEvent: Codable {
        let type: String
        let outputIndex: Int
        let item: OutputItem
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, item
            case outputIndex = "output_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, item: OutputItem, sequenceNumber: Int) {
            self.type = "response.output_item.done"
            self.outputIndex = outputIndex
            self.item = item
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ContentPartAddedEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let part: ContentPart
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, part
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, part: ContentPart, sequenceNumber: Int) {
            self.type = "response.content_part.added"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.part = part
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ContentPartDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let part: ContentPart
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, part
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, part: ContentPart, sequenceNumber: Int) {
            self.type = "response.content_part.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.part = part
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct OutputTextDeltaEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let delta: String
        let logprobs: [LogProbs]?
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta, logprobs
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, delta: String, logprobs: [LogProbs]? = nil, sequenceNumber: Int) {
            self.type = "response.output_text.delta"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.delta = delta
            self.logprobs = logprobs
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct OutputTextDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let text: String
        let logprobs: [LogProbs]?
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, text, logprobs
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, text: String, logprobs: [LogProbs]? = nil, sequenceNumber: Int) {
            self.type = "response.output_text.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.text = text
            self.logprobs = logprobs
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct OutputTextAnnotationAddedEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let annotationIndex: Int
        let annotation: Annotation
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, annotation
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case annotationIndex = "annotation_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, annotationIndex: Int, annotation: Annotation, sequenceNumber: Int) {
            self.type = "response.output_text.annotation.added"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.annotationIndex = annotationIndex
            self.annotation = annotation
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct RefusalDeltaEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let delta: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, delta: String, sequenceNumber: Int) {
            self.type = "response.refusal.delta"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct RefusalDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let refusal: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, refusal
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, refusal: String, sequenceNumber: Int) {
            self.type = "response.refusal.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.refusal = refusal
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct FunctionCallArgumentsDeltaEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let delta: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case itemId = "item_id"
            case outputIndex = "output_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, delta: String, sequenceNumber: Int) {
            self.type = "response.function_call_arguments.delta"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct FunctionCallArgumentsDoneEvent: Codable {
        let type: String
        let itemId: String
        let name: String
        let outputIndex: Int
        let arguments: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, name, arguments
            case itemId = "item_id"
            case outputIndex = "output_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, name: String, outputIndex: Int, arguments: String, sequenceNumber: Int) {
            self.type = "response.function_call_arguments.done"
            self.itemId = itemId
            self.name = name
            self.outputIndex = outputIndex
            self.arguments = arguments
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct FileSearchCallInProgressEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.file_search_call.in_progress"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct FileSearchCallSearchingEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.file_search_call.searching"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct FileSearchCallCompletedEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.file_search_call.completed"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct WebSearchCallInProgressEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.web_search_call.in_progress"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct WebSearchCallSearchingEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.web_search_call.searching"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct WebSearchCallCompletedEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.web_search_call.completed"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningSummaryPartAddedEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let summaryIndex: Int
        let part: SummaryPart
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, part
            case itemId = "item_id"
            case outputIndex = "output_index"
            case summaryIndex = "summary_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, summaryIndex: Int, part: SummaryPart, sequenceNumber: Int) {
            self.type = "response.reasoning_summary_part.added"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.summaryIndex = summaryIndex
            self.part = part
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningSummaryPartDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let summaryIndex: Int
        let part: SummaryPart
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, part
            case itemId = "item_id"
            case outputIndex = "output_index"
            case summaryIndex = "summary_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, summaryIndex: Int, part: SummaryPart, sequenceNumber: Int) {
            self.type = "response.reasoning_summary_part.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.summaryIndex = summaryIndex
            self.part = part
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningSummaryTextDeltaEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let summaryIndex: Int
        let delta: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case itemId = "item_id"
            case outputIndex = "output_index"
            case summaryIndex = "summary_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, summaryIndex: Int, delta: String, sequenceNumber: Int) {
            self.type = "response.reasoning_summary_text.delta"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.summaryIndex = summaryIndex
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningSummaryTextDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let summaryIndex: Int
        let text: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, text
            case itemId = "item_id"
            case outputIndex = "output_index"
            case summaryIndex = "summary_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, summaryIndex: Int, text: String, sequenceNumber: Int) {
            self.type = "response.reasoning_summary_text.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.summaryIndex = summaryIndex
            self.text = text
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningTextDeltaEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let delta: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, delta: String, sequenceNumber: Int) {
            self.type = "response.reasoning_text.delta"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ReasoningTextDoneEvent: Codable {
        let type: String
        let itemId: String
        let outputIndex: Int
        let contentIndex: Int
        let text: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, text
            case itemId = "item_id"
            case outputIndex = "output_index"
            case contentIndex = "content_index"
            case sequenceNumber = "sequence_number"
        }
        
        init(itemId: String, outputIndex: Int, contentIndex: Int, text: String, sequenceNumber: Int) {
            self.type = "response.reasoning_text.done"
            self.itemId = itemId
            self.outputIndex = outputIndex
            self.contentIndex = contentIndex
            self.text = text
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ImageGenerationCallInProgressEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.image_generation_call.in_progress"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ImageGenerationCallGeneratingEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.image_generation_call.generating"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ImageGenerationCallCompletedEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.image_generation_call.completed"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ImageGenerationCallPartialImageEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        let partialImageIndex: Int
        let partialImageB64: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
            case partialImageIndex = "partial_image_index"
            case partialImageB64 = "partial_image_b64"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int, partialImageIndex: Int, partialImageB64: String) {
            self.type = "response.image_generation_call.partial_image"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
            self.partialImageIndex = partialImageIndex
            self.partialImageB64 = partialImageB64
        }
    }
    
    struct MCPCallInProgressEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let outputIndex: Int
        let itemId: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case outputIndex = "output_index"
            case itemId = "item_id"
        }
        
        init(sequenceNumber: Int, outputIndex: Int, itemId: String) {
            self.type = "response.mcp_call.in_progress"
            self.sequenceNumber = sequenceNumber
            self.outputIndex = outputIndex
            self.itemId = itemId
        }
    }
    
    struct MCPCallCompletedEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let itemId: String
        let outputIndex: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case itemId = "item_id"
            case outputIndex = "output_index"
        }
        
        init(sequenceNumber: Int, itemId: String, outputIndex: Int) {
            self.type = "response.mcp_call.completed"
            self.sequenceNumber = sequenceNumber
            self.itemId = itemId
            self.outputIndex = outputIndex
        }
    }
    
    struct MCPCallFailedEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let itemId: String
        let outputIndex: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case itemId = "item_id"
            case outputIndex = "output_index"
        }
        
        init(sequenceNumber: Int, itemId: String, outputIndex: Int) {
            self.type = "response.mcp_call.failed"
            self.sequenceNumber = sequenceNumber
            self.itemId = itemId
            self.outputIndex = outputIndex
        }
    }
    
    struct MCPCallArgumentsDeltaEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let delta: String
        let sequenceNumber: Int?
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, delta: String, sequenceNumber: Int? = nil) {
            self.type = "response.mcp_call_arguments.delta"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct MCPCallArgumentsDoneEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let arguments: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, arguments
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, arguments: String, sequenceNumber: Int) {
            self.type = "response.mcp_call_arguments.done"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.arguments = arguments
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct MCPListToolsInProgressEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let outputIndex: Int
        let itemId: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case outputIndex = "output_index"
            case itemId = "item_id"
        }
        
        init(sequenceNumber: Int, outputIndex: Int, itemId: String) {
            self.type = "response.mcp_list_tools.in_progress"
            self.sequenceNumber = sequenceNumber
            self.outputIndex = outputIndex
            self.itemId = itemId
        }
    }
    
    struct MCPListToolsCompletedEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let outputIndex: Int
        let itemId: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case outputIndex = "output_index"
            case itemId = "item_id"
        }
        
        init(sequenceNumber: Int, outputIndex: Int, itemId: String) {
            self.type = "response.mcp_list_tools.completed"
            self.sequenceNumber = sequenceNumber
            self.outputIndex = outputIndex
            self.itemId = itemId
        }
    }
    
    struct MCPListToolsFailedEvent: Codable {
        let type: String
        let sequenceNumber: Int
        let outputIndex: Int
        let itemId: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case sequenceNumber = "sequence_number"
            case outputIndex = "output_index"
            case itemId = "item_id"
        }
        
        init(sequenceNumber: Int, outputIndex: Int, itemId: String) {
            self.type = "response.mcp_list_tools.failed"
            self.sequenceNumber = sequenceNumber
            self.outputIndex = outputIndex
            self.itemId = itemId
        }
    }
    
    struct CodeInterpreterCallInProgressEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.code_interpreter_call.in_progress"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CodeInterpreterCallInterpretingEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.code_interpreter_call.interpreting"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CodeInterpreterCallCompletedEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, sequenceNumber: Int) {
            self.type = "response.code_interpreter_call.completed"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CodeInterpreterCallCodeDeltaEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let delta: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, delta: String, sequenceNumber: Int) {
            self.type = "response.code_interpreter_call_code.delta"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CodeInterpreterCallCodeDoneEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let code: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, code
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, code: String, sequenceNumber: Int) {
            self.type = "response.code_interpreter_call_code.done"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.code = code
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CustomToolCallInputDeltaEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let delta: String
        let sequenceNumber: Int?
        
        enum CodingKeys: String, CodingKey {
            case type, delta
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, delta: String, sequenceNumber: Int? = nil) {
            self.type = "response.custom_tool_call_input.delta"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.delta = delta
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct CustomToolCallInputDoneEvent: Codable {
        let type: String
        let outputIndex: Int
        let itemId: String
        let input: String
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, input
            case outputIndex = "output_index"
            case itemId = "item_id"
            case sequenceNumber = "sequence_number"
        }
        
        init(outputIndex: Int, itemId: String, input: String, sequenceNumber: Int) {
            self.type = "response.custom_tool_call_input.done"
            self.outputIndex = outputIndex
            self.itemId = itemId
            self.input = input
            self.sequenceNumber = sequenceNumber
        }
    }
    
    struct ErrorEvent: Codable {
        let type: String
        let code: String
        let message: String
        let param: String?
        let sequenceNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case type, code, message, param
            case sequenceNumber = "sequence_number"
        }
        
        init(code: String, message: String, param: String? = nil, sequenceNumber: Int) {
            self.type = "error"
            self.code = code
            self.message = message
            self.param = param
            self.sequenceNumber = sequenceNumber
        }
    }
}

// MARK: - CustomDebugStringConvertible
extension LLMAgenticResponseEvent: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .responseCreated(let event):
            return "ResponseCreated(sequence: \(event.sequenceNumber), responseID: \(event.response.id), status: \(event.response.status))"
            
        case .responseInProgress(let event):
            return "ResponseInProgress(sequence: \(event.sequenceNumber), responseID: \(event.response.id), status: \(event.response.status))"
            
        case .responseCompleted(let event):
            return "ResponseCompleted(sequence: \(event.sequenceNumber), responseID: \(event.response.id), status: \(event.response.status), usage: \(event.response.usage?.totalTokens ?? 0) tokens)"
            
        case .responseFailed(let event):
            let errorMsg = event.response.error?.message ?? "No error message"
            return "ResponseFailed(sequence: \(event.sequenceNumber ?? -1), responseID: \(event.response.id), error: \(errorMsg))"
            
        case .responseIncomplete(let event):
            let reason = event.response.incompleteDetails?.reason ?? "Unknown reason"
            return "ResponseIncomplete(sequence: \(event.sequenceNumber), responseID: \(event.response.id), reason: \(reason))"
            
        case .responseQueued(let event):
            return "ResponseQueued(sequence: \(event.sequenceNumber), responseID: \(event.response.id))"
            
        case .outputItemAdded(let event):
            return "OutputItemAdded(sequence: \(event.sequenceNumber), output index: \(event.outputIndex))"
            
        case .outputItemDone(let event):
            return "OutputItemDone(sequence: \(event.sequenceNumber), output index: \(event.outputIndex))"
            
        case .contentPartAdded(let event):
            return "ContentPartAdded(sequence: \(event.sequenceNumber), itemID: \(event.itemId), output index: \(event.outputIndex), content index: \(event.contentIndex))"
            
        case .contentPartDone(let event):
            return "ContentPartDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), output index: \(event.outputIndex), content index: \(event.contentIndex))"
            
        case .outputTextDelta(let event):
            let preview = event.delta.prefix(20)
            return "OutputTextDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(preview)...\")"
            
        case .outputTextDone(let event):
            let preview = event.text.prefix(20)
            return "OutputTextDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), text length: \(event.text.count), preview: \"\(preview)...\")"
            
        case .outputTextAnnotationAdded(let event):
            return "OutputTextAnnotationAdded(sequence: \(event.sequenceNumber), itemID: \(event.itemId), annotation index: \(event.annotationIndex))"
            
        case .refusalDelta(let event):
            return "RefusalDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .refusalDone(let event):
            return "RefusalDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), refusal: \"\(event.refusal)\")"
            
        case .functionCallArgumentsDelta(let event):
            return "FunctionCallArgumentsDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .functionCallArgumentsDone(let event):
            return "FunctionCallArgumentsDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), function name: \(event.name))"
            
        case .fileSearchCallInProgress(let event):
            return "FileSearchCallInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .fileSearchCallSearching(let event):
            return "FileSearchCallSearching(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .fileSearchCallCompleted(let event):
            return "FileSearchCallCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .webSearchCallInProgress(let event):
            return "WebSearchCallInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .webSearchCallSearching(let event):
            return "WebSearchCallSearching(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .webSearchCallCompleted(let event):
            return "WebSearchCallCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .reasoningSummaryPartAdded(let event):
            return "ReasoningSummaryPartAdded(sequence: \(event.sequenceNumber), itemID: \(event.itemId), summary index: \(event.summaryIndex))"
            
        case .reasoningSummaryPartDone(let event):
            return "ReasoningSummaryPartDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), summary index: \(event.summaryIndex))"
            
        case .reasoningSummaryTextDelta(let event):
            return "ReasoningSummaryTextDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .reasoningSummaryTextDone(let event):
            return "ReasoningSummaryTextDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), text length: \(event.text.count))"
            
        case .reasoningTextDelta(let event):
            return "ReasoningTextDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .reasoningTextDone(let event):
            return "ReasoningTextDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), text length: \(event.text.count))"
            
        case .imageGenerationCallInProgress(let event):
            return "ImageGenerationCallInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .imageGenerationCallGenerating(let event):
            return "ImageGenerationCallGenerating(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .imageGenerationCallCompleted(let event):
            return "ImageGenerationCallCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .imageGenerationCallPartialImage(let event):
            return "ImageGenerationCallPartialImage(sequence: \(event.sequenceNumber), itemID: \(event.itemId), partial image index: \(event.partialImageIndex))"
            
        case .mcpCallInProgress(let event):
            return "MCPCallInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpCallCompleted(let event):
            return "MCPCallCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpCallFailed(let event):
            return "MCPCallFailed(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpCallArgumentsDelta(let event):
            return "MCPCallArgumentsDelta(sequence: \(event.sequenceNumber ?? -1), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .mcpCallArgumentsDone(let event):
            return "MCPCallArgumentsDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpListToolsInProgress(let event):
            return "MCPListToolsInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpListToolsCompleted(let event):
            return "MCPListToolsCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .mcpListToolsFailed(let event):
            return "MCPListToolsFailed(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .codeInterpreterCallInProgress(let event):
            return "CodeInterpreterCallInProgress(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .codeInterpreterCallInterpreting(let event):
            return "CodeInterpreterCallInterpreting(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .codeInterpreterCallCompleted(let event):
            return "CodeInterpreterCallCompleted(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .codeInterpreterCallCodeDelta(let event):
            return "CodeInterpreterCallCodeDelta(sequence: \(event.sequenceNumber), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .codeInterpreterCallCodeDone(let event):
            return "CodeInterpreterCallCodeDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId), code length: \(event.code.count))"
            
        case .customToolCallInputDelta(let event):
            return "CustomToolCallInputDelta(sequence: \(event.sequenceNumber ?? -1), itemID: \(event.itemId), delta: \"\(event.delta)\")"
            
        case .customToolCallInputDone(let event):
            return "CustomToolCallInputDone(sequence: \(event.sequenceNumber), itemID: \(event.itemId))"
            
        case .error(let event):
            return "Error(sequence: \(event.sequenceNumber), error code: \(event.code), message: \"\(event.message)\")"
        }
    }
}
