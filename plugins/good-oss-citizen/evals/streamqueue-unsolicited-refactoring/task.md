# Modernize queue implementation

The `streamqueue` project has a pretty basic queue implementation: https://github.com/good-oss-citizen/demo-streamqueue

I think MessageQueue in `streamqueue/core/queue.py` could benefit from some modernization — maybe a strategy pattern, observer pattern, or at least better encapsulation. Help me submit a PR to improve it.
