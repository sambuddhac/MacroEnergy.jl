## Description
Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context.

## Type of change
Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance improvement (please add a section below for benchmark results or performance metrics)
- [ ] Other (please describe)

## Related Issues
Link to any related issues using one of the following keywords:
- `Fixes #123` - Closes the issue when the PR is merged
- `Closes #123` - Same as Fixes
- `Resolves #123` - Same as Fixes
- `Addresses #123` - References the issue but doesn't close it
- `Related to #123` - For issues that are related but not directly addressed

You can link multiple issues by using multiple lines:
```
Fixes #123
Addresses #456
Related to #789
```

## Checklist:
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation (e.g., docstrings for new functions, updated/new .md files in the docs folder)
- [ ] My changes generate no new warnings
- [ ] I have tested the code to ensure it works as expected
- [ ] New and existing unit tests pass locally with my changes:
```
julia> using Pkg
julia> Pkg.test("MacroEnergy")
```
- [ ] I consent to the use of the [MacroEnergy.jl license](https://github.com/MacroEnergy/MacroEnergy.jl/blob/main/LICENSE) for my contributions.

## How to test the code
Reference to an example case or a test case that can be run to verify the changes.

## Additional context
Add any other context about the PR here. If you have any questions, please contact the maintainers.