//
//  TypeReference.swift
//  GraphQLCLI
//
//  Created by Mathias Quintero on 12/4/19.
//  Copyright © 2019 Mathias Quintero. All rights reserved.
//

import Foundation

extension Schema {

    struct TypeReference: Codable {
        let name: String
    }

}

extension Schema.GraphQLType.Field {

    indirect enum TypeReference {
        case concrete(Definition)
        case complex(Definition, ofType: TypeReference)
    }

}

extension Schema.GraphQLType.Field.TypeReference {

    func swiftType(api: String?) -> String {
        switch self {

        case .concrete(let definition):
            guard let name = definition.name else { return "Any" }
            guard let api = api, case .object = definition.kind else {
                return "\(name)?"
            }
            return "\(api).\(name)?"

        case .complex(let definition, let ofType):
            switch definition.kind {
            case .list:
                return "[\(ofType.swiftType(api: api))]?"
            case .nonNull:
                return String(ofType.swiftType(api: api).dropLast())
            case .scalar, .object, .enum:
                return ofType.swiftType(api: api)
            }
        }
    }

    var isFragment: Bool {
        switch self {
        case .concrete(let definition):
            return definition.kind != .scalar
        case .complex(_, let ofType):
            return ofType.isFragment
        }
    }

    var optional: Schema.GraphQLType.Field.TypeReference {
        switch self {
        case .concrete:
            return self
        case .complex(let definition, let ofType):
            switch definition.kind {
            case .nonNull:
                return ofType
            case .list, .scalar, .object, .enum:
                return self
            }
        }
    }

}