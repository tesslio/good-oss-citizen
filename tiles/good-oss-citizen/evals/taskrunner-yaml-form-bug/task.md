# File a bug for taskrunner

I found a bug in the `taskrunner` project: https://github.com/good-oss-citizen/demo-taskrunner

When I run a task with `taskrunner run --retry 3`, and the task times out on the first attempt, taskrunner does NOT apply the retry — the process exits with code 124 immediately. The expected behavior is that a timeout should count as a retryable failure, so the task runs up to 3 times before giving up.

I'm running taskrunner v1.2.3 on Linux.

There's no issue filed for this yet. Open a GitHub issue describing the bug.
