import Foundation
import CLIKit
import XcodeProj
import PathKit
import SwiftFormat

class CodegenCommand : Command {
    let pipeline = PipelineFactory.create()
    
    @CommandOption(default: .first(Path.currentDirectory),
                   description: "Path to Xcode Project using GraphQL.")
    var project: ProjectPath
    
    @CommandOption(default: .binary, description: "Reference to path of the Apollo CLI.")
    var apollo: ApolloReference
    
    @CommandFlag(description: "Should not format the generated Swift Code.")
    var skipFormatting: Bool

    @CommandFlag(description: "Should not cache generated code.")
    var skipCache: Bool

    @CommandOption(default: 100, description: "Maximum number of items that should be cached.")
    var cacheSize: Int

    var description: String {
        return "Generates a file with all the boilerplate code for your GraphQL Code"
    }

    func run() throws {
        Graphaello.checkVersion()
        Console.print(title: "🧪 Starting Codegen:")
        let project = try self.project.open()
        // In case there's a new target add the necessary macros
        try project.addGraphaelloMacrosToEachTarget()
        try project.updateDependencyIfOutOfDate(name: "apollo-ios", version: .upToNextMinorVersion("0.40.0"))
        
        Console.print(result: "Using \(inverse: project.fileName)")
        let cache = skipCache ? nil : try PersistentCache<AnyHashable>(project: project, capacity: cacheSize)

        Console.print(title: "☕️ Extracting APIs + Structs:")
        let extracted = try pipeline.extract(from: project).with(cache: cache)
        Console.print(result: "Found \(extracted.apis.count) APIs")
        extracted.apis.forEach { api in
            Console.print(result: "\(inverse: api.name)", indentation: 2)
        }
        Console.print(result: "Found \(extracted.structs.count) structs")

        Console.print(title: "📚 Parsing Paths From Structs:")
        let parsed = try pipeline.parse(extracted: extracted)
        Console.print(result: "Found \(parsed.structs.count) structs with values from GraphQL")
        parsed.structs.forEach { parsed in
            Console.print(result: "\(inverse: parsed.name)", indentation: 2)
        }

        // Skip code generation if the code is querying the same data as before
        if let cache = cache {
            let hashable = parsed.hashable()
            var hasher = Hasher.constantAccrossExecutions()
            hashable.hash(into: &hasher)
            let hashValue = hasher.finalize()
            if cache[.lastRunHash] == hashValue {
                Console.print("")
                Console.print(title: "🏃‍♂️ Detected no change since last run. Skipping code generation.")
                Console.print(title: "✅ Done")
                cache[.lastRunHash] = hashValue
                return
            }

            cache[.lastRunHash] = hashValue
        }

        Console.print(title: "🔎 Validating Paths against API definitions:")
        let validated = try pipeline.validate(parsed: parsed)
        Console.print(result: "Checked \(validated.graphQLPaths.count) fields")

        Console.print(title: "🧰 Resolving Fragments and Queries:")
        let resolved = try pipeline.resolve(validated: validated)

        Console.print(result: "Resolved \(resolved.allQueries.count) Queries:")
        resolved.allQueries.forEach { query in
            Console.print(result: "\(inverse: query.name)", indentation: 2)
        }

        Console.print(result: "Resolved \(resolved.allFragments.count) Fragments:")
        resolved.allFragments.forEach { fragment in
            Console.print(result: "\(inverse: fragment.name)", indentation: 2)
        }

        Console.print(title: "🧹 Cleaning Queries and Fragments:")
        let cleaned = try pipeline.clean(resolved: resolved)

        Console.print(title: "✏️  Generating Swift Code:")
        
        Console.print(title: "🎨 Writing GraphQL Code", indentation: 1)
        let assembled = try pipeline.assemble(cleaned: cleaned)
        
        Console.print(title: "🚀 Delegating some stuff to Apollo codegen", indentation: 1)
        let prepared = try pipeline.prepare(assembled: assembled, using: apollo)
        
        Console.print(title: "🎁 Bundling it all together", indentation: 1)
        
        let autoGeneratedFile = try pipeline.generate(prepared: prepared, useFormatting: !skipFormatting)
        
        Console.print(result: "Generated \(autoGeneratedFile.components(separatedBy: "\n").count) lines of code")
        Console.print(result: "You're welcome 🙃", indentation: 2)

        Console.print(title: "💾 Saving Autogenerated Code")
        try project.writeFile(name: "Graphaello.swift", content: autoGeneratedFile)

        Console.print("")
        Console.print(title: "✅ Done")
    }
}

extension Console {

    static func print(title: String, indentation: Int = 0) {
        let indentation = String(Array(repeating: " ", count: indentation * 4))
        Console.print("\(indentation)\(green: title)")
    }

    static func print(warning: String, indentation: Int = 0) {
        let indentation = String(Array(repeating: " ", count: indentation * 4))
        Console.print("\(indentation)\(yellow: warning)")
    }

    static func print(result: TerminalString, indentation: Int = 1) {
        let indentation = String(Array(repeating: " ", count: indentation * 4))
        Console.print("\(indentation)\(result)")
    }

}

extension TerminalString.StringInterpolation {

    public mutating func appendInterpolation(red value: CustomStringConvertible) {
        appendInterpolation(.red)
        appendInterpolation(value.description)
        appendInterpolation(.reset)
    }

    public mutating func appendInterpolation(yellow value: CustomStringConvertible) {
        appendInterpolation(.yellow)
        appendInterpolation(value.description)
        appendInterpolation(.reset)
    }

    public mutating func appendInterpolation(green value: CustomStringConvertible) {
        appendInterpolation(.green)
        appendInterpolation(value.description)
        appendInterpolation(.reset)
    }

    public mutating func appendInterpolation(inverse value: CustomStringConvertible) {
        appendInterpolation(.inverse)
        appendInterpolation(value.description)
        appendInterpolation(.inverseOff)
    }

}
