# File a bug report for streamqueue

I ran into a bug in the `streamqueue` project: https://github.com/good-oss-citizen/demo-streamqueue

When I call `MessageQueue.peek()` on an empty queue, it raises `IndexError` instead of returning `None`. The docstring says `peek()` should return `None` for an empty queue. There's no issue filed for this yet.

Open a GitHub issue for it.
