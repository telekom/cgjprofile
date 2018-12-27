import Darwin
import cgjprofileCore

let tool = cgjprofileTool()

do {
    let result = try tool.run()
    exit(result)
} catch {
    fputs("Whoops! An error occurred: \(error)", stderr)
    exit(EXIT_FAILURE)
}
