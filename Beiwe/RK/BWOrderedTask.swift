// identical except for superclass to BWNavigatableTask
class BWOrderedTask: ORKOrderedTask {
    override func step(after step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        // log.info("stepAfterStep for \(step?.identifier)")
        return super.step(after: step, with: result)
    }

    override func step(before step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        // log.info("stepBeforeStep for \(step?.identifier)")
        return super.step(before: step, with: result)
    }
}
