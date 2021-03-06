import CLIKit

enum ProjectPath {
    case specific(Path)
    case first(Path)
}

extension ProjectPath: CommandArgumentValue {
    init(argumentValue: String) throws {
        let localPath = Path.currentDirectory + argumentValue
        if localPath.exists {
            self = try ProjectPath(path: localPath)
        }

        let globalPath = Path(argumentValue)
        if globalPath.exists {
            self = try ProjectPath(path: globalPath)
            return
        }

        throw ArgumentError.pathDoesNotExist(argumentValue)
    }

    init(path: Path) throws {
        if path.isProject {
            self = .specific(path)
        } else if path.isDirectory {
            self = .first(path)
        } else {
            throw ArgumentError.fileIsNotAProject(path)
        }
    }

    var description: String {
        switch self {
        case .first(let path):
            if path == Path.currentDirectory {
                return "First Project in the current working directory"
            } else {
                return "First Project"
            }
        case .specific(let path):
            return path.description
        }
    }
}

extension ProjectPath {

    private func path() throws -> Path {
        switch self {
        case .specific(let path):
            return path
        case .first(let path):
            return try path
                .contentsOfDirectory(fullPaths: true)
                .first { $0.isProject } ?! ArgumentError.noProjectFound(at: path)
        }
    }

    func open() throws -> Project {
        return try Project(path: try path())
    }

}

extension Path {

    var isProject: Bool {
        return ["xcodeproj", "xcworkspace"].contains(`extension`)
    }

}
