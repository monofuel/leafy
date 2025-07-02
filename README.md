# Leafy 🍃



A comprehensive Gitea API client library for Nim.

## Features

- 🔐 **Authentication** - Support for API tokens
- 👥 **Users** - Get user information, search users
- 📦 **Repositories** - CRUD operations, forking, listing
- 🐛 **Issues** - Create, edit, list, close/reopen issues
- 🔀 **Pull Requests** - Create, list, merge pull requests
- 💬 **Comments** - Manage issue and PR comments
- 🏷️ **Labels** - Full label management
- 🎯 **Milestones** - Create and manage milestones
- 📋 **Organizations** - List organizations and members
- 🚀 **Releases** - Get and list releases
- ⚙️ **Actions / Workflows** - Trigger workflows via the workflow_dispatch API

## Installation

Add to your `.nimble` file:

```nim
requires "leafy"
```

Or install directly:

```bash
nimble install leafy
```

## Quick Start

```nim
import leafy

# Create client (automatically uses GITEA_TOKEN env var)
let client = newGiteaClient("https://gitea.example.com")
defer: client.close()

# Get repository
let repo = client.getRepository("owner", "repo-name")
echo repo.full_name

# List issues
let issues = client.listIssues("owner", "repo-name", "open")
for issue in issues:
  echo &"#{issue.number}: {issue.title}"

# Create an issue
let payload = CreateIssuePayload(
  title: "Bug report",
  body: option("Found a bug in the code")
)
let newIssue = client.createIssue("owner", "repo-name", payload)
```

## API Coverage

### User Operations
- `getCurrentUser()` - Get authenticated user
- `getUser(username)` - Get user by username
- `searchUsers(query)` - Search for users

### Repository Operations
- `checkRepository(owner, repo)` - Check if repository exists
- `getRepository(owner, repo)` - Get repository details
- `listUserRepositories(username)` - List user's repositories
- `listCurrentUserRepositories()` - List authenticated user's repos
- `listOrganizationRepositories(org)` - List organization's repos
- `createRepository(payload)` - Create new repository
- `deleteRepository(owner, repo)` - Delete repository
- `forkRepository(owner, repo)` - Fork repository

### Issue Operations
- `listIssues(owner, repo, state, filters...)` - List issues with filtering
- `getIssue(owner, repo, number)` - Get specific issue
- `createIssue(owner, repo, payload)` - Create new issue
- `editIssue(owner, repo, number, payload)` - Edit existing issue
- `closeIssue(owner, repo, number)` - Close issue
- `reopenIssue(owner, repo, number)` - Reopen issue

### Pull Request Operations
- `listPullRequests(owner, repo, state)` - List pull requests
- `getPullRequest(owner, repo, number)` - Get specific PR
- `createPullRequest(owner, repo, payload)` - Create new PR
- `mergePullRequest(owner, repo, number, method)` - Merge PR

### Comment Operations
- `listIssueComments(owner, repo, number)` - List issue comments
- `createIssueComment(owner, repo, number, payload)` - Create comment
- `editIssueComment(owner, repo, commentId, payload)` - Edit comment
- `deleteIssueComment(owner, repo, commentId)` - Delete comment

### Label Operations
- `listLabels(owner, repo)` - List repository labels
- `getLabel(owner, repo, labelId)` - Get specific label
- `createLabel(owner, repo, payload)` - Create new label
- `editLabel(owner, repo, labelId, payload)` - Edit label
- `deleteLabel(owner, repo, labelId)` - Delete label

### Milestone Operations
- `listMilestones(owner, repo, state)` - List milestones
- `getMilestone(owner, repo, milestoneId)` - Get specific milestone
- `createMilestone(owner, repo, payload)` - Create milestone
- `deleteMilestone(owner, repo, milestoneId)` - Delete milestone

### Release Operations
- `listReleases(owner, repo)` - List releases
- `getRelease(owner, repo, releaseId)` - Get specific release
- `getReleaseByTag(owner, repo, tag)` - Get release by tag
- `getLatestRelease(owner, repo)` - Get latest release

### Actions / Workflows

- `dispatchWorkflow(owner, repo, workflow, gitRef = "main", inputs = Table[string,string])` - Trigger a manual workflow run (equivalent to GitHub's `workflow_dispatch`)

### Organization Operations
- `listOrganizations()` - List user's organizations
- `getOrganization(org)` - Get organization details
- `listOrganizationMembers(org)` - List organization members

## Authentication

You can use the library without authentication for public repositories, but you'll need an API token for:
- Private repositories
- Creating/editing content
- Higher rate limits

Generate a token in your Gitea instance:
1. Go to Settings → Applications
2. Generate New Token
3. Select appropriate scopes

```nim
# With explicit token
let client = newGiteaClient("https://gitea.example.com", "your-token")

# With environment variable (GITEA_TOKEN)
export GITEA_TOKEN="your-token"
let client = newGiteaClient("https://gitea.example.com")

# Without authentication (public repos only)
let client = newGiteaClient("https://gitea.example.com")
```

The client will automatically use the `GITEA_TOKEN` environment variable if no token is explicitly provided.

## Error Handling

The library raises `GiteaError` exceptions for API-related errors:

```nim
try:
  let repo = client.getRepository("owner", "nonexistent")
except GiteaError as e:
  echo "API Error: ", e.msg
except Exception as e:
  echo "Other error: ", e.msg
```

## Examples

See `example.nim` for comprehensive usage examples.

To run the example:

```bash
# Set environment variables
export GITEA_URL="https://your-gitea-instance.com"
export GITEA_TOKEN="your-api-token"  # optional

# Run example
nim c -r example.nim
```

## Testing

The library includes two types of tests:

### Unit Tests
Unit tests verify library functionality without external dependencies:

```bash
# Run unit tests
nimble test

# Or directly
nim c -r tests/test.nim
```

### Integration Tests
Integration tests connect to a real Gitea instance. They require:
- A running Gitea instance at `192.168.90.12:3000`
- A repository `monofuel/leafy` with issue #1

```bash
# Run integration tests
nimble integration

# Or directly
nim c -r tests/integration_test.nim
```

### All Tests
Run both unit and integration tests:

```bash
nimble test_all
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality (unit tests required, integration tests encouraged)
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Dependencies

- [curly](https://github.com/guzba/curly) - HTTP client
- [jsony](https://github.com/treeform/jsony) - JSON serialization
