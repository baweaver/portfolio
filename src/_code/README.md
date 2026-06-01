# Code Blocks (`_code`)

Testable code blocks for blog articles. Each article gets a subdirectory.

## Conventions

- One directory per article, named to match the post slug
- Files contain inline RSpec specs above the code (excluded from article output)
- Meta-syntax comments mark segments for extraction:
  - `# segment: name` — starts a named segment
  - `# end: name` — ends a named segment
- Everything above the first `# segment:` line is treated as test-only code
- Extracted segments are de-indented to their least indentation level

## Running specs

```sh
bundle exec rspec src/_code/  # all code specs
bundle exec rspec src/_code/beyond-enumerable-windows/  # one article
```

Lefthook runs specs automatically on pre-push for changed `_code` files.
