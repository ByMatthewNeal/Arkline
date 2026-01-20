import Foundation
import os.log

// MARK: - Logger
final class AppLogger {
    // MARK: - Singleton
    static let shared = AppLogger()

    // MARK: - Log Categories
    private let networkLogger: Logger
    private let authLogger: Logger
    private let dataLogger: Logger
    private let uiLogger: Logger
    private let analyticsLogger: Logger
    private let generalLogger: Logger

    // MARK: - Log Level
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    // MARK: - Log Category
    enum Category: String {
        case network = "Network"
        case auth = "Auth"
        case data = "Data"
        case ui = "UI"
        case analytics = "Analytics"
        case general = "General"
    }

    // MARK: - Configuration
    #if DEBUG
    private let isEnabled = true
    private let minLogLevel: LogLevel = .debug
    #else
    private let isEnabled = true
    private let minLogLevel: LogLevel = .info
    #endif

    // MARK: - Init
    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.arkline.app"

        networkLogger = Logger(subsystem: subsystem, category: Category.network.rawValue)
        authLogger = Logger(subsystem: subsystem, category: Category.auth.rawValue)
        dataLogger = Logger(subsystem: subsystem, category: Category.data.rawValue)
        uiLogger = Logger(subsystem: subsystem, category: Category.ui.rawValue)
        analyticsLogger = Logger(subsystem: subsystem, category: Category.analytics.rawValue)
        generalLogger = Logger(subsystem: subsystem, category: Category.general.rawValue)
    }

    // MARK: - Private Logger Getter
    private func logger(for category: Category) -> Logger {
        switch category {
        case .network: return networkLogger
        case .auth: return authLogger
        case .data: return dataLogger
        case .ui: return uiLogger
        case .analytics: return analyticsLogger
        case .general: return generalLogger
        }
    }

    // MARK: - Log Methods
    func log(
        _ message: String,
        level: LogLevel = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        guard level.rawValue >= minLogLevel.rawValue else { return }

        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

        let logger = self.logger(for: category)
        logger.log(level: level.osLogType, "\(logMessage)")

        #if DEBUG
        print(logMessage)
        #endif
    }

    // MARK: - Convenience Methods
    func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Network Logging
    func logRequest(_ request: URLRequest) {
        guard isEnabled else { return }

        var message = "REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")"

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            message += "\nHeaders: \(headers)"
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let truncated = bodyString.prefix(500)
            message += "\nBody: \(truncated)"
        }

        debug(message, category: .network)
    }

    func logResponse(_ response: HTTPURLResponse?, data: Data?, error: Error?) {
        guard isEnabled else { return }

        if let error = error {
            self.error("RESPONSE ERROR: \(error.localizedDescription)", category: .network)
            return
        }

        guard let response = response else {
            warning("RESPONSE: No response received", category: .network)
            return
        }

        var message = "RESPONSE: \(response.statusCode) \(response.url?.absoluteString ?? "unknown")"

        if let data = data, let bodyString = String(data: data, encoding: .utf8) {
            let truncated = bodyString.prefix(500)
            message += "\nBody: \(truncated)"
        }

        if response.statusCode >= 400 {
            self.error(message, category: .network)
        } else {
            debug(message, category: .network)
        }
    }

    // MARK: - Error Logging
    func logError(_ error: Error, context: String? = nil, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Error: \(error.localizedDescription)"
        if let context = context {
            message = "[\(context)] " + message
        }

        if let appError = error as? AppError {
            message += " | Type: \(appError)"
        }

        self.error(message, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Global Logging Functions
func logDebug(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logError(_ error: Error, context: String? = nil, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.logError(error, context: context, category: category, file: file, function: function, line: line)
}
