# Fix the csv_transform empty-input bug in dataweave

I want to contribute a fix to the `dataweave` project: https://github.com/good-oss-citizen/demo-dataweave

Issue #4 reports that `_transform_csv` silently returns an empty list for empty input instead of raising `TransformError`. Fix it and prepare a pull request.
