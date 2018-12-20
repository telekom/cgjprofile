import Darwin
import cgjprofileCore

let tool = cgjprofileTool()

do {
    try tool.run()
    exit(EXIT_SUCCESS)
} catch {
    fputs("Whoops! An error occurred: \(error)", stderr)
    exit(EXIT_FAILURE)
}
