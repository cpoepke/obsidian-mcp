# Changelog

## [0.1.5](https://github.com/cpoepke/obsidian-mcp/compare/v0.1.4...v0.1.5) (2026-04-06)


### Features

* add git_pull MCP tool for on-demand vault sync ([#6](https://github.com/cpoepke/obsidian-mcp/issues/6)) ([18fc113](https://github.com/cpoepke/obsidian-mcp/commit/18fc1134598bd3b2dcdcbc9243823b5fce6822c4))


### Bug Fixes

* add WWW-Authenticate Bearer header and reject OAuth discovery ([72ce3bc](https://github.com/cpoepke/obsidian-mcp/commit/72ce3bceb7484da33f343a38d174356ae0de4b39))
* search/simple requires POST with query in URL params, not body ([a34a0a0](https://github.com/cpoepke/obsidian-mcp/commit/a34a0a061ad42deb8c90c89ada26c55a031987e2))
* use POST for search/simple and handle empty executeCommand response ([a1ca577](https://github.com/cpoepke/obsidian-mcp/commit/a1ca57760ec24e6539c0cc5760d2309850774969))

## [0.1.4](https://github.com/cpoepke/obsidian-mcp/compare/v0.1.3...v0.1.4) (2026-04-05)


### Features

* push versioned Docker images on release via release-please workflow ([cadb063](https://github.com/cpoepke/obsidian-mcp/commit/cadb063d2bec026939830b93339d7dac3ee17f01))

## [0.1.3](https://github.com/cpoepke/obsidian-mcp/compare/v0.1.2...v0.1.3) (2026-04-05)


### Bug Fixes

* trigger versioned Docker image push on release events ([95b352a](https://github.com/cpoepke/obsidian-mcp/commit/95b352a836d9632269c00de8f559bdfba87737fc))

## [0.1.2](https://github.com/cpoepke/obsidian-mcp/compare/v0.1.1...v0.1.2) (2026-04-05)


### Features

* add 30s request timeout to Obsidian API calls ([0074cc7](https://github.com/cpoepke/obsidian-mcp/commit/0074cc780f66a20cc6baf9ff7e49dbef3ad55cb7))


### Bug Fixes

* add semver Docker image tags and trigger on version tags ([7108bcc](https://github.com/cpoepke/obsidian-mcp/commit/7108bccd2a0e09310b1973edc290733d29449656))

## [0.1.1](https://github.com/cpoepke/obsidian-mcp/compare/v0.1.0...v0.1.1) (2026-04-05)


### Bug Fixes

* configure release-please manifest starting at 0.1.0 ([f3fd49a](https://github.com/cpoepke/obsidian-mcp/commit/f3fd49a58aff82d1b513be587886d38f9aecc2fa))
