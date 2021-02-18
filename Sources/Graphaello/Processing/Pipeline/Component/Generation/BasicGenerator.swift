import Foundation
import CLIKit
struct BasicGenerator: Generator {

    private let structureAPIVersion = 12
    private let apiCodeGenVersion = 3
    private let connectionFragmentCodeGenVersion = 2
    
    func generate(prepared: Project.State<Stage.Prepared>, useFormatting: Bool) throws -> String {
        let usedTypesThatTriggerCacheMiss = prepared
            .usedTypes
            .filter { !$0.kind.isFragment }
            .map(\.name)
            .sorted()

        Console.print(title: "👻 Code generat method started opened", indentation: 1)
        return try code(context: ["usedTypes" : prepared.usedTypes]) {
            StructureAPI().withFormatting(format: useFormatting).cached(alongWith: structureAPIVersion, using: prepared.cache)
            prepared.apis.map { api in
                // TODO: - check this step
                return api
                    .withFormatting(format: useFormatting)
                    .cached(
                        alongWith: usedTypesThatTriggerCacheMiss, apiCodeGenVersion,
                        using: prepared.cache
                    )
            }

            // TODO: Find a way to cache structs as well
            prepared.structs.map { prepared in
                // TODO: - check this step
                return prepared
                    .withFormatting(format: useFormatting)
            }

            prepared.allConnectionFragments.map { connectionFragment in
                // TODO: - check this step
                return connectionFragment
                    .withFormatting(format: useFormatting)
                    .cached(
                        alongWith: connectionFragmentCodeGenVersion,
                        using: prepared.cache
                    )
            }

            prepared.responses.map { $0.code }
        }
    }
    
}

extension Project.State where CurrentStage == Stage.Prepared {

    var usedTypes: Set<Schema.GraphQLType> {
        return structs.reduce([]) { $0.union($1.usedTypes) }
    }

}

extension Struct where CurrentStage == Stage.Prepared {

    var usedTypes: Set<Schema.GraphQLType> {
        return properties.reduce([]) { $0.union($1.usedTypes) }
    }

}

extension Property where CurrentStage == Stage.Prepared {

    var usedTypes: Set<Schema.GraphQLType> {
        guard let path = graphqlPath else { return [] }
        let arguments = path.components.flatMap { $0.usedTypes(api: path.resolved.validated.api) }
        return Set(arguments).union([path.components.last!.validated.underlyingType])
    }

}

extension Stage.Cleaned.Component {

    func usedTypes(api: API) -> Set<Schema.GraphQLType> {
        return validated.reference.usedTypes(api: api)
    }

}

extension Stage.Validated.Component.Reference {

    func usedTypes(api: API) -> Set<Schema.GraphQLType> {
        switch self {
        case .casting, .fragment, .type:
            return []
        case .field(let field):
            return Set(field.arguments.compactMap { api[$0.type.underlyingTypeName]?.graphQLType })
        }
    }

}
