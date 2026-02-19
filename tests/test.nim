import
  std/[unittest, options, os, strformat, sequtils, strutils],
  ../src/leafy

## Unit tests for the Leafy Gitea API client library

suite "Gitea Client Creation":
  test "can create client without token":
    let client = newGiteaClient("https://gitea.example.com")
    check client.baseUrl == "https://gitea.example.com"
    # Token should be empty if no GITEA_TOKEN env var and no explicit token
    client.close()

  test "can create client with explicit token":
    let client = newGiteaClient("https://gitea.example.com", "test-token")
    check client.baseUrl == "https://gitea.example.com"
    check client.token == "test-token"
    client.close()
  
  test "can create client with environment token":
    # Save original env var
    let originalToken = getEnv("GITEA_TOKEN", "")
    
    # Set test token
    putEnv("GITEA_TOKEN", "env-test-token")
    
    let client = newGiteaClient("https://gitea.example.com")
    check client.baseUrl == "https://gitea.example.com"
    check client.token == "env-test-token"
    client.close()
    
    # Restore original env var
    if originalToken != "":
      putEnv("GITEA_TOKEN", originalToken)
    else:
      delEnv("GITEA_TOKEN")
  
  test "explicit token overrides environment token":
    # Save original env var
    let originalToken = getEnv("GITEA_TOKEN", "")
    
    # Set test env token
    putEnv("GITEA_TOKEN", "env-token")
    
    # Create client with explicit token
    let client = newGiteaClient("https://gitea.example.com", "explicit-token")
    check client.baseUrl == "https://gitea.example.com"
    check client.token == "explicit-token"
    client.close()
    
    # Restore original env var
    if originalToken != "":
      putEnv("GITEA_TOKEN", originalToken)
    else:
      delEnv("GITEA_TOKEN")

suite "Payload Creation":
  test "can create issue payload":
    let payload = CreateIssuePayload(
      title: "Test Issue",
      body: option("Test description"),
      labels: option(@[1, 2])
    )
    check payload.title == "Test Issue"
    check payload.body.isSome
    check payload.body.get == "Test description"
    check payload.labels.isSome
    check payload.labels.get == @[1, 2]

  test "can create pull request payload":
    let payload = CreatePullRequestPayload(
      title: "Test PR",
      body: option("Test PR description"),
      head: "feature-branch",
      base: "main"
    )
    check payload.title == "Test PR"
    check payload.head == "feature-branch"
    check payload.base == "main"

  test "can create repository payload":
    let payload = CreateRepositoryPayload(
      name: "test-repo",
      description: option("Test repository"),
      private: option(false),
      auto_init: option(true)
    )
    check payload.name == "test-repo"
    check payload.description.isSome
    check payload.private.isSome
    check payload.private.get == false

  test "can create label payload":
    let payload = CreateLabelPayload(
      name: "bug",
      color: "ff0000",
      description: option("Bug reports")
    )
    check payload.name == "bug"
    check payload.color == "ff0000"
    check payload.description.isSome

  test "can create comment payload":
    let payload = CreateCommentPayload(body: "This is a test comment")
    check payload.body == "This is a test comment"

suite "Actions Model Creation":
  test "can create action run model":
    let run = GiteaActionRun(
      id: 42,
      name: "CI",
      head_branch: "main",
      head_sha: "abc123",
      path: ".gitea/workflows/build.yml",
      display_title: "Build",
      run_number: 7,
      event: "push",
      status: "completed",
      conclusion: option("success"),
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:10:00Z"
    )
    check run.id == 42
    check run.status == "completed"
    check run.conclusion.isSome

  test "can create action job model":
    let job = GiteaActionJob(
      id: 77,
      run_id: option(42),
      run_url: option("https://gitea.example.com/api/v1/repos/o/r/actions/runs/42"),
      name: "test",
      status: "in_progress",
      conclusion: none(string),
      started_at: option("2026-01-01T00:01:00Z"),
      completed_at: none(string)
    )
    check job.id == 77
    check job.run_id.isSome
    check job.completed_at.isNone

  test "can create action artifact model":
    let artifact = GiteaActionArtifact(
      id: 9,
      name: "build-output",
      size_in_bytes: 1024,
      archive_download_url: option("https://gitea.example.com/download"),
      expired: false,
      created_at: "2026-01-01T00:05:00Z",
      updated_at: "2026-01-01T00:06:00Z"
    )
    check artifact.name == "build-output"
    check artifact.size_in_bytes == 1024
    check artifact.expired == false

suite "URL Path Construction":
  test "API prefix is correct":
    check ApiPathPrefix == "/api/v1"

suite "Utility Functions":
  test "can format issue with $ operator":
    let user = GiteaUser(
      id: 1,
      login: "testuser",
      full_name: "Test User",
      email: "test@example.com",
      avatar_url: "https://example.com/avatar.png",
      username: "testuser"
    )
    
    let label = GiteaLabel(
      id: 1,
      name: "bug",
      color: "ff0000",
      description: "Bug reports",
      url: "https://example.com/label"
    )
    
    let issue = GiteaIssue(
      id: 123,
      number: 1,
      title: "Test Issue",
      body: "This is a test issue",
      user: user,
      labels: option(@[label]),
      state: "open",
      is_locked: false,
      comments: 0,
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
      html_url: "https://gitea.example.com/test/test/issues/1"
    )
    
    let formatted = $issue
    check "Test Issue" in formatted
    check "testuser" in formatted
    check "bug" in formatted
    check "open" in formatted

  test "can format pull request with $ operator":
    let user = GiteaUser(
      id: 1,
      login: "testuser",
      full_name: "Test User",
      email: "test@example.com",
      avatar_url: "https://example.com/avatar.png",
      username: "testuser"
    )
    
    let repo = GiteaRepository(
      id: 1,
      name: "test-repo",
      full_name: "test/test-repo",
      description: "Test repository",
      empty: false,
      private: false,
      fork: false,
      `template`: false,
      mirror: false,
      size: 1024,
      language: "Nim",
      html_url: "https://gitea.example.com/test/test-repo",
      ssh_url: "git@gitea.example.com:test/test-repo.git",
      clone_url: "https://gitea.example.com/test/test-repo.git",
      original_url: "",
      website: "",
      stars_count: 0,
      forks_count: 0,
      watchers_count: 0,
      open_issues_count: 0,
      open_pr_counter: 0,
      release_counter: 0,
      default_branch: "main",
      archived: false,
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
      owner: user
    )
    
    let headBranch = PullRequestBranch(
      label: "feature",
      `ref`: "feature",
      sha: "abc123",
      repo: repo
    )
    
    let baseBranch = PullRequestBranch(
      label: "main",
      `ref`: "main", 
      sha: "def456",
      repo: repo
    )
    
    let pr = GiteaPullRequest(
      id: 123,
      number: 1,
      title: "Test PR",
      body: "This is a test PR",
      user: user,
      labels: none(seq[GiteaLabel]),
      state: "open",
      is_locked: false,
      comments: 0,
      html_url: "https://gitea.example.com/test/test-repo/pulls/1",
      diff_url: "https://gitea.example.com/test/test-repo/pulls/1.diff",
      patch_url: "https://gitea.example.com/test/test-repo/pulls/1.patch",
      mergeable: true,
      merged: false,
      head: headBranch,
      base: baseBranch,
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z"
    )
    
    let formatted = $pr
    check "Test PR" in formatted
    check "testuser" in formatted
    check "feature" in formatted
    check "main" in formatted
    check "open" in formatted

echo "✅ Unit tests completed!"
echo "   Tests verify library functionality without external dependencies"
echo "   Run integration tests with: nim c -r tests/integration_test.nim"
