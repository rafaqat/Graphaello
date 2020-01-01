//
//  ResolvedComponentCollector.swift
//  Graphaello
//
//  Created by Mathias Quintero on 09.12.19.
//  Copyright © 2019 Mathias Quintero. All rights reserved.
//

import Foundation

struct ResolvedComponentCollector: ResolvedValueCollector {
    func collect(from value: Stage.Validated.Component,
                 in parent: Stage.Resolved.Path) -> StructResolution.Result<CollectedPath.Valid?> {
        
        switch (value.reference, value.parsed) {
        case (.casting(.up), _):
            return .resolved(nil)
        case (.casting(.down), _):
            return .resolved(.typeConditional(value.underlyingType, .empty))
            
        case (.field(let field), .property):
            return .resolved(.scalar(.direct(field)))
        
        case (_, .fragment), (.fragment, _):
            switch parent.referencedFragment {
            case .some(.fragment(let fragment)):
                return .resolved(.fragment(fragment))
            case .some(.connection(let connection)):
                return .resolved(.connection(connection))
            case .none:
                return .missingFragment
            }
            
        case (.field(let field), .call(_, let arguments)):
            return .resolved(.scalar(.call(field, arguments)))
        
        }
    }
}