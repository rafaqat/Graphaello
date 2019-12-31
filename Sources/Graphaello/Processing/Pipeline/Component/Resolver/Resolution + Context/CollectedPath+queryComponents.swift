//
//  CollectedPath+components.swift
//  Graphaello
//
//  Created by Mathias Quintero on 09.12.19.
//  Copyright © 2019 Mathias Quintero. All rights reserved.
//

import Foundation

extension CollectedPath.Valid {

    func queryComponents(propertyName: String) throws -> [Field : GraphQLComponent] {
        switch self {
        case .scalar(let field):
            return [field : .scalar]
        case .object(let field, let valid):
            return [field : .object(valid.object(propertyName: propertyName))]
        case .connection(let connection):
            throw GraphQLFragmentResolverError.cannotIncludeFragmentsInsideAQuery(connection.fragment)
        case .fragment(let fragment):
            throw GraphQLFragmentResolverError.cannotIncludeFragmentsInsideAQuery(fragment)
        case .typeConditional(let type, _):
            throw GraphQLFragmentResolverError.cannotDowncastQueryToType(type)
        }
    }
    
}