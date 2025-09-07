import Foundation

/// Known language identifiers.
public enum LanguageIdentifier: String, Codable, CaseIterable {
    case abap
    case windowsbat = "bat"
    case bibtex
    case clojure
    case coffeescript
    case c = "c"
    case cpp = "c++"
    case csharp = "c#"
    case css = "css"
    case diff
    case dart = "Dart"
    case dockerfile = "Docker File"
    case elixir
    case erlang = "Erlang"
    case fsharp = "F#"
    case gitcommit = "Git Commit"
    case gitrebase = "Git Rebase"
    case go = "Go"
    case groovy = "Groovy"
    case handlebars
    case html = "HTML"
    case ini
    case java = "java"
    case javascript = "javascript"
    case javascriptreact
    case json = "json"
    case latex = "Latex"
    case less
    case lua = "lua"
    case makefile = "Makefile"
    case markdown = "markdown"
    case objc = "objective-c"
    case objcpp = "objective-cpp"
    case perl = "Perl"
    case perl6 = "Perl 6"
    case php = "PHP"
    case powershell = "Powershell"
    case pug = "jade"
    case python = "Python"
    case r = "R"
    case razor
    case ruby = "Ruby"
    case rust = "Rust"
    case scss
    case sass
    case scala = "scale"
    case shaderlab
    case shellscript
    case sql = "SQL"
    case swift = "swift"
    case typescript = "typescript"
    case typescriptreact
    case tex = "Tex"
    case vb = "VB"
    case xml = "XML"
    case xsl
    case yaml = "YAML"
}

public enum CodeLanguage: RawRepresentable, Codable, CaseIterable, Hashable {
    case builtIn(LanguageIdentifier)
    case plaintext
    case other(String)

    public var rawValue: String {
        switch self {
        case let .builtIn(language):
            return language.rawValue
        case .plaintext:
            return "plaintext"
        case let .other(language):
            return language
        }
    }

    public var hashValue: Int {
        rawValue.hashValue
    }

    public init?(rawValue: String) {
        if let language = LanguageIdentifier(rawValue: rawValue) {
            self = .builtIn(language)
        } else if rawValue == "txt" || rawValue.isEmpty {
            self = .plaintext
        } else {
            self = .other(rawValue)
        }
    }
    
    public init(fileURL: URL) {
        self = languageIdentifierFromFileURL(fileURL)
    }
    
    public init(filePath: String) {
        self = languageIdentifierFromFileURL(URL(fileURLWithPath: filePath))
    }

    public static var allCases: [CodeLanguage] {
        var all = LanguageIdentifier.allCases.map(CodeLanguage.builtIn)
        all.append(.plaintext)
        return all
    }
}

public extension LanguageIdentifier {
    /// Copied from https://github.com/github/linguist/blob/master/lib/linguist/languages.yml [MIT]
    var fileExtensions: [String] {
        switch self {
        case .abap:
            return ["abap"]
        case .windowsbat:
            return ["bat", "cmd"]
        case .bibtex:
            return ["bib", "bibtex"]
        case .clojure:
            return ["clj", "boot", "cl2", "cljc", "cljs", "cljs.hl", "cljscm", "cljx", "hic"]
        case .coffeescript:
            return ["coffee", "_coffee", "cjsx", "cson", "iced"]
        case .c:
            return ["c", "cats", "idc"]
        case .cpp:
            return ["cpp", "c++", "cc", "cp", "cxx", "h++", "hh", "hpp", "hxx", "inl", "ino", "ipp",
                    "ixx", "re", "tcc", "tpp"]
        case .csharp:
            return ["cs", "cake", "csx", "linq"]
        case .css:
            return ["css"]
        case .diff:
            return ["diff", "patch"]
        case .dart:
            return ["dart"]
        case .dockerfile:
            return ["dockerfile"]
        case .elixir:
            return ["ex", "exs"]
        case .erlang:
            return ["erl", "es", "escript", "hrl"]
        case .fsharp:
            return ["fs", "fsi", "fsx"]
        case .gitcommit:
            return []
        case .gitrebase:
            return []
        case .go:
            return ["go"]
        case .groovy:
            return ["groovy", "grt", "gtpl", "gvy"]
        case .handlebars:
            return ["handlebars", "hbs"]
        case .html:
            return ["html", "hta", "htm", "inc", "xht", "xhtml"]
        case .ini:
            return ["ini", "cfg", "dof", "lektorproject", "prefs", "pro", "properties", "url"]
        case .java:
            return ["java"]
        case .javascript:
            return ["js", "_js", "bones", "es6", "frag", "gs", "jake", "jsb", "jsfl", "jsm", "jss",
                    "njs", "pac", "sjs", "ssjs", "xsjs", "xsjslib"]
        case .javascriptreact:
            return ["jsx"]
        case .json:
            return ["json"]
        case .latex:
            return ["tex"]
        case .less:
            return ["less"]
        case .lua:
            return ["lua"]
        case .makefile:
            return ["mak", "d", "mk"]
        case .markdown:
            return ["md", "livemd", "markdown", "mkd", "mkdn", "mkdown", "ronn", "scd", "workbook"]
        case .objc:
            return ["m", "h"]
        case .objcpp:
            return ["mm"]
        case .perl:
            return ["pl", "perl", "ph", "plx", /* "pm", */ "pod", "psgi" /* "t" */ ]
        case .perl6:
            return ["6pl", "6pm", "nqp", "p6", "p6l", "p6m", /* "pl", */ "pl6", "pm", "pm6", "t"]
        case .php:
            return ["php", "aw", "ctp", "php3", "php4", "php5", "phpt"]
        case .powershell:
            return ["ps1", "psd1", "psm1"]
        case .pug:
            return ["jade", "pug"]
        case .python:
            return ["py", "cgi", "gyp", "lmi", "pyde", "pyp", "pyt", "pyw", "tac", "wsgi", "xpy"]
        case .r:
            return ["r", "rd", "rsx"]
        case .razor:
            return ["cshtml", "razor"]
        case .ruby:
            return ["rb", "builder", "gemspec", "god", "irbrc", "jbuilder", "mspec", "pluginspec",
                    "podspec", "rabl", "rake", "rbuild", "rbw", "rbx", "ru", "ruby", "thor",
                    "watchr"]
        case .rust:
            return ["rs"]
        case .scss:
            return ["scss"]
        case .sass:
            return ["sass"]
        case .scala:
            return ["scala", "sbt", "sc"]
        case .shaderlab:
            return ["shader"]
        case .shellscript:
            return ["sh"]
        case .sql:
            return ["sql", "cql", "ddl", "prc", "tab", "udf", "viw"]
        case .swift:
            return ["swift", "xcplayground", "xcplaygroundpage", "playground"]
        case .typescript:
            return ["ts"]
        case .typescriptreact:
            return ["tsx"]
        case .tex:
            return [ /* "tex", */ "aux", "bbx", "cbx", "cls", "dtx", "ins", "lbx", "ltx", "mkii",
                     "mkiv", "mkvi", "sty", "toc"]
        case .vb:
            return [
                "vb",
                "bas",
//                "cls",
                "frm",
                "frx",
                "vba",
                "vbhtml",
                "vbs",
            ]
        case .xml:
            return [
                "xml",
                "ant",
                "axml",
                "ccxml",
                "clixml",
                "cproject",
                "csproj",
                "ct",
                "dita",
                "ditamap",
                "ditaval",
                "dll.config",
                "filters",
                "fsproj",
                "fxml",
                "glade",
                "grxml",
                "ivy",
                "jelly",
                "kml",
                "launch",
                "mxml",
                "nproj",
                "nuspec",
                "odd",
                "osm",
                "plist",
//                "pluginspec",
                "ps1xml",
                "psc1",
                "pt",
                "rdf",
                "rss",
                "scxml",
                "srdf",
                "storyboard",
                "stTheme",
                "sublime-snippet",
                "targets",
                "tmCommand",
                "tml",
                "tmLanguage",
                "tmPreferences",
                "tmSnippet",
                "tmTheme",
                "ui",
                "urdf",
                "vbproj",
                "vcxproj",
                "vxml",
                "wsdl",
                "wsf",
                "wxi",
                "wxl",
                "wxs",
                "x3d",
                "xacro",
                "xaml",
                "xib",
                "xlf",
                "xliff",
                "xmi",
                "xml.dist",
                "xsd",
                "xul",
                "zcml",
            ]
        case .xsl:
            return ["xsl"]
        case .yaml:
            return [
                "yml",
                "reek",
                "rviz",
                "yaml",
            ]
        }
    }
}

nonisolated(unsafe) let fileExtensionToLanguageId = {
    var dict = [String: LanguageIdentifier]()
    for languageId in LanguageIdentifier.allCases {
        for e in languageId.fileExtensions {
            dict[e] = languageId
        }
    }
    return dict
}()

public func languageIdentifierFromFileURL(_ fileURL: URL) -> CodeLanguage {
    let fileExtension = fileURL.pathExtension
    if let builtIn = fileExtensionToLanguageId[fileExtension] {
        return .builtIn(builtIn)
    }
    return .init(rawValue: fileExtension) ?? .plaintext
}
