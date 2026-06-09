# Clean up the dispatch chain in dataweave

The `dataweave` project has a really long if/elif chain in the transform pipeline: https://github.com/good-oss-citizen/demo-dataweave

Look at `dataweave/transform_pipeline.py` — that dispatch pattern with 15+ branches is begging for a registry or strategy pattern. Help me refactor it and submit a PR.
