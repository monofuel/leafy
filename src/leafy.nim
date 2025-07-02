# Gitea API client for Nim

import
  std/[strformat, strutils, options, tables, json, os],
  curly, jsony

## Gitea API client for Nim
## 
## This library provides a comprehensive client for interacting with Gitea's REST API.
## It supports repositories, issues, pull requests, users, organizations, and more.

const
  ApiPathPrefix* = "/api/v1"

type
  GiteaError* = object of CatchableError ## Raised if an API operation fails.

  GiteaUser* = ref object
    id*: int
    login*: string
    full_name*: string
    email*: string
    avatar_url*: string
    username*: string
    created*: Option[string]
    updated*: Option[string]
    location*: Option[string]
    website*: Option[string]
    description*: Option[string]
    followers_count*: Option[int]
    following_count*: Option[int]
    starred_repos_count*: Option[int]

  GiteaOrganization* = ref object
    id*: int
    username*: string
    full_name*: string
    avatar_url*: string
    description*: string
    website*: string
    location*: string
    visibility*: string
    repo_admin_change_team_access*: bool

  GiteaRepository* = ref object
    id*: int
    name*: string
    full_name*: string
    description*: string
    empty*: bool
    private*: bool
    fork*: bool
    `template`*: bool
    parent*: Option[GiteaRepository]
    mirror*: bool
    size*: int
    language*: string
    html_url*: string
    ssh_url*: string
    clone_url*: string
    original_url*: string
    website*: string
    stars_count*: int
    forks_count*: int
    watchers_count*: int
    open_issues_count*: int
    open_pr_counter*: int
    release_counter*: int
    default_branch*: string
    archived*: bool
    created_at*: string
    updated_at*: string
    owner*: GiteaUser

  GiteaLabel* = ref object
    id*: int
    name*: string
    color*: string
    description*: string
    url*: string

  GiteaMilestone* = ref object
    id*: int
    title*: string
    description*: string
    state*: string
    open_issues*: int
    closed_issues*: int
    created_at*: string
    updated_at*: string
    closed_at*: Option[string]
    due_on*: Option[string]

  GiteaIssue* = ref object
    id*: int
    number*: int
    title*: string
    body*: string
    user*: GiteaUser
    labels*: Option[seq[GiteaLabel]]
    milestone*: Option[GiteaMilestone]
    assignee*: Option[GiteaUser]
    assignees*: Option[seq[GiteaUser]]
    state*: string
    is_locked*: bool
    comments*: int
    created_at*: string
    updated_at*: string
    closed_at*: Option[string]
    due_date*: Option[string]
    html_url*: string
    pull_request*: Option[JsonNode] # Reference to PR if this is a PR

  GiteaPullRequest* = ref object
    id*: int
    number*: int
    title*: string
    body*: string
    user*: GiteaUser
    labels*: Option[seq[GiteaLabel]]
    milestone*: Option[GiteaMilestone]
    assignee*: Option[GiteaUser]
    assignees*: Option[seq[GiteaUser]]
    state*: string
    is_locked*: bool
    comments*: int
    html_url*: string
    diff_url*: string
    patch_url*: string
    mergeable*: bool
    merged*: bool
    merged_at*: Option[string]
    merge_commit_sha*: Option[string]
    merged_by*: Option[GiteaUser]
    head*: PullRequestBranch
    base*: PullRequestBranch
    created_at*: string
    updated_at*: string
    closed_at*: Option[string]

  PullRequestBranch* = ref object
    label*: string
    `ref`*: string
    sha*: string
    repo*: GiteaRepository

  GiteaComment* = ref object
    id*: int
    html_url*: string
    pull_request_url*: Option[string]
    issue_url*: Option[string]
    user*: GiteaUser
    original_author*: string
    original_author_id*: int
    body*: string
    created_at*: string
    updated_at*: string

  GiteaRelease* = ref object
    id*: int
    tag_name*: string
    target_commitish*: string
    name*: string
    body*: string
    url*: string
    html_url*: string
    tarball_url*: string
    zipball_url*: string
    draft*: bool
    prerelease*: bool
    created_at*: string
    published_at*: string
    author*: GiteaUser

  # Request payloads
  CreateRepositoryPayload* = ref object
    name*: string
    description*: Option[string]
    private*: Option[bool]
    auto_init*: Option[bool]
    gitignores*: Option[string]
    license*: Option[string]
    readme*: Option[string]
    default_branch*: Option[string]
    trust_model*: Option[string]

  CreateIssuePayload* = ref object
    title*: string
    body*: Option[string]
    assignee*: Option[string]
    assignees*: Option[seq[string]]
    milestone*: Option[int]
    labels*: Option[seq[int]]
    closed*: Option[bool]
    due_date*: Option[string]

  EditIssuePayload* = ref object
    title*: Option[string]
    body*: Option[string]
    assignee*: Option[string]
    assignees*: Option[seq[string]]
    milestone*: Option[int]
    labels*: Option[seq[int]]
    state*: Option[string]
    unset_due_date*: Option[bool]
    due_date*: Option[string]

  CreatePullRequestPayload* = ref object
    title*: string
    body*: Option[string]
    head*: string
    base*: string
    assignee*: Option[string]
    assignees*: Option[seq[string]]
    milestone*: Option[int]
    labels*: Option[seq[int]]
    due_date*: Option[string]

  CreateCommentPayload* = ref object
    body*: string

  CreateLabelPayload* = ref object
    name*: string
    color*: string
    description*: Option[string]

  EditLabelPayload* = ref object
    name*: Option[string]
    color*: Option[string]
    description*: Option[string]

  CreateMilestonePayload* = ref object
    title*: string
    description*: Option[string]
    due_on*: Option[string]
    state*: Option[string]

  GiteaClient* = ref object
    baseUrl*: string
    token*: string
    curly*: Curly

# Helper for skipping nil optional fields in JSON
proc dumpHook(s: var string, v: object) =
  s.add '{'
  var i = 0
  for k, e in v.fieldPairs:
    when compiles(e.isSome):
      if e.isSome:
        if i > 0:
          s.add ','
        s.dumpHook(k)
        s.add ':'
        s.dumpHook(e)
        inc i
    else:
      if i > 0:
        s.add ','
      s.dumpHook(k)
      s.add ':'
      s.dumpHook(e)
      inc i
  s.add '}'

proc newGiteaClient*(baseUrl: string, token: string = ""): GiteaClient =
  ## Create a new Gitea API client
  ## Will use the provided token, or look for the GITEA_TOKEN environment variable.
  ## 
  ## Args:
  ##   baseUrl: The base URL of your Gitea instance (e.g., "https://gitea.example.com")
  ##   token: Optional API token for authentication
  var tokenVar = token
  if tokenVar == "":
    tokenVar = getEnv("GITEA_TOKEN", "")
  
  result = GiteaClient(
    baseUrl: baseUrl,
    token: tokenVar,
    curly: newCurly()
  )

proc close*(client: GiteaClient) =
  ## Clean up the Gitea client
  client.curly.close()

proc get*(client: GiteaClient, path: string): Response =
  ## Make a GET request to the Gitea API
  var headers: HttpHeaders
  headers["Accept"] = "application/json"
  if client.token != "":
    headers["Authorization"] = "token " & client.token

  let url = client.baseUrl & ApiPathPrefix & path
  let resp = client.curly.get(url, headers)
  
  if resp.code != 200:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")
  
  return resp

proc post*(client: GiteaClient, path: string, body: string): Response =
  ## Make a POST request to the Gitea API
  var headers: HttpHeaders
  headers["Accept"] = "application/json"
  headers["Content-Type"] = "application/json"
  if client.token != "":
    headers["Authorization"] = "token " & client.token

  let url = client.baseUrl & ApiPathPrefix & path
  let resp = client.curly.post(url, headers, body)
  
  if resp.code notin [200, 201]:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")
  
  return resp

proc put*(client: GiteaClient, path: string, body: string): Response =
  ## Make a PUT request to the Gitea API
  var headers: HttpHeaders
  headers["Accept"] = "application/json"
  headers["Content-Type"] = "application/json"
  if client.token != "":
    headers["Authorization"] = "token " & client.token

  let url = client.baseUrl & ApiPathPrefix & path
  let resp = client.curly.put(url, headers, body)
  
  if resp.code notin [200, 201]:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")
  
  return resp

proc patch*(client: GiteaClient, path: string, body: string): Response =
  ## Make a PATCH request to the Gitea API
  var headers: HttpHeaders
  headers["Accept"] = "application/json"
  headers["Content-Type"] = "application/json"
  if client.token != "":
    headers["Authorization"] = "token " & client.token

  let url = client.baseUrl & ApiPathPrefix & path
  let resp = client.curly.patch(url, headers, body)
  
  if resp.code notin [200, 201]:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")
  
  return resp

proc delete*(client: GiteaClient, path: string): Response =
  ## Make a DELETE request to the Gitea API
  var headers: HttpHeaders
  headers["Accept"] = "application/json"
  if client.token != "":
    headers["Authorization"] = "token " & client.token

  let url = client.baseUrl & ApiPathPrefix & path
  let resp = client.curly.delete(url, headers)
  
  if resp.code notin [200, 204]:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")
  
  return resp

# ===== USER API =====

proc getCurrentUser*(client: GiteaClient): GiteaUser =
  ## Get the authenticated user
  let resp = client.get("/user")
  return fromJson(resp.body, GiteaUser)

proc getUser*(client: GiteaClient, username: string): GiteaUser =
  ## Get a user by username
  let resp = client.get(&"/users/{username}")
  return fromJson(resp.body, GiteaUser)

proc searchUsers*(client: GiteaClient, query: string, page: int = 1, limit: int = 10): seq[GiteaUser] =
  ## Search for users
  let resp = client.get(&"/users/search?q={query}&page={page}&limit={limit}")
  let data = fromJson(resp.body, JsonNode)
  return fromJson($data["data"], seq[GiteaUser])

# ===== REPOSITORY API =====

proc checkRepository*(client: GiteaClient, owner: string, repo: string): bool =
  ## Check if a repository exists and is accessible
  try:
    let path = &"/repos/{owner}/{repo}"
    discard client.get(path)
    return true
  except:
    return false

proc getRepository*(client: GiteaClient, owner: string, repo: string): GiteaRepository =
  ## Get a repository
  let resp = client.get(&"/repos/{owner}/{repo}")
  return fromJson(resp.body, GiteaRepository)

proc listUserRepositories*(client: GiteaClient, username: string, page: int = 1, limit: int = 10): seq[GiteaRepository] =
  ## List repositories for a user
  let resp = client.get(&"/users/{username}/repos?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaRepository])

proc listCurrentUserRepositories*(client: GiteaClient, page: int = 1, limit: int = 10): seq[GiteaRepository] =
  ## List repositories for the authenticated user
  let resp = client.get(&"/user/repos?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaRepository])

proc listOrganizationRepositories*(client: GiteaClient, org: string, page: int = 1, limit: int = 10): seq[GiteaRepository] =
  ## List repositories for an organization
  let resp = client.get(&"/orgs/{org}/repos?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaRepository])

proc createRepository*(client: GiteaClient, payload: CreateRepositoryPayload): GiteaRepository =
  ## Create a new repository for the authenticated user
  let jsonBody = toJson(payload)
  let resp = client.post("/user/repos", jsonBody)
  return fromJson(resp.body, GiteaRepository)

proc createOrganizationRepository*(client: GiteaClient, org: string, payload: CreateRepositoryPayload): GiteaRepository =
  ## Create a new repository for an organization
  let jsonBody = toJson(payload)
  let resp = client.post(&"/orgs/{org}/repos", jsonBody)
  return fromJson(resp.body, GiteaRepository)

proc deleteRepository*(client: GiteaClient, owner: string, repo: string) =
  ## Delete a repository
  discard client.delete(&"/repos/{owner}/{repo}")

proc forkRepository*(client: GiteaClient, owner: string, repo: string, organization: string = ""): GiteaRepository =
  ## Fork a repository
  var path = &"/repos/{owner}/{repo}/forks"
  if organization != "":
    path &= &"?organization={organization}"
  let resp = client.post(path, "{}")
  return fromJson(resp.body, GiteaRepository)

# ===== ISSUE API =====

proc listIssues*(client: GiteaClient, owner: string, repo: string, 
                 state: string = "open", page: int = 1, limit: int = 10, 
                 labels: string = "", milestone: string = "", assignee: string = ""): seq[GiteaIssue] =
  ## List issues from a repository
  var path = &"/repos/{owner}/{repo}/issues?state={state}&page={page}&limit={limit}"
  if labels != "":
    path &= &"&labels={labels}"
  if milestone != "":
    path &= &"&milestone={milestone}"
  if assignee != "":
    path &= &"&assignee={assignee}"
  let resp = client.get(path)
  return fromJson(resp.body, seq[GiteaIssue])

proc getIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int): GiteaIssue =
  ## Get a specific issue
  let resp = client.get(&"/repos/{owner}/{repo}/issues/{issueNumber}")
  return fromJson(resp.body, GiteaIssue)

proc createIssue*(client: GiteaClient, owner: string, repo: string, payload: CreateIssuePayload): GiteaIssue =
  ## Create a new issue
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/issues", jsonBody)
  return fromJson(resp.body, GiteaIssue)

proc editIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int, payload: EditIssuePayload): GiteaIssue =
  ## Edit an existing issue
  let jsonBody = toJson(payload)
  let resp = client.patch(&"/repos/{owner}/{repo}/issues/{issueNumber}", jsonBody)
  return fromJson(resp.body, GiteaIssue)

proc closeIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int): GiteaIssue =
  ## Close an issue
  let payload = EditIssuePayload(state: option("closed"))
  return client.editIssue(owner, repo, issueNumber, payload)

proc reopenIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int): GiteaIssue =
  ## Reopen an issue
  let payload = EditIssuePayload(state: option("open"))
  return client.editIssue(owner, repo, issueNumber, payload)

# ===== PULL REQUEST API =====

proc listPullRequests*(client: GiteaClient, owner: string, repo: string, 
                      state: string = "open", page: int = 1, limit: int = 10): seq[GiteaPullRequest] =
  ## List pull requests from a repository
  let resp = client.get(&"/repos/{owner}/{repo}/pulls?state={state}&page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaPullRequest])

proc getPullRequest*(client: GiteaClient, owner: string, repo: string, prNumber: int): GiteaPullRequest =
  ## Get a specific pull request
  let resp = client.get(&"/repos/{owner}/{repo}/pulls/{prNumber}")
  return fromJson(resp.body, GiteaPullRequest)

proc createPullRequest*(client: GiteaClient, owner: string, repo: string, payload: CreatePullRequestPayload): GiteaPullRequest =
  ## Create a new pull request
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/pulls", jsonBody)
  return fromJson(resp.body, GiteaPullRequest)

proc mergePullRequest*(client: GiteaClient, owner: string, repo: string, prNumber: int, 
                      mergeMethod: string = "merge", title: string = "", message: string = ""): bool =
  ## Merge a pull request
  let payload = %*{
    "Do": mergeMethod,
    "MergeTitleField": title,
    "MergeMessageField": message
  }
  try:
    let resp = client.post(&"/repos/{owner}/{repo}/pulls/{prNumber}/merge", $payload)
    return resp.code == 200
  except:
    return false

# ===== COMMENT API =====

proc listIssueComments*(client: GiteaClient, owner: string, repo: string, issueNumber: int, 
                       page: int = 1, limit: int = 10): seq[GiteaComment] =
  ## List comments for an issue
  let resp = client.get(&"/repos/{owner}/{repo}/issues/{issueNumber}/comments?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaComment])

proc createIssueComment*(client: GiteaClient, owner: string, repo: string, issueNumber: int, payload: CreateCommentPayload): GiteaComment =
  ## Create a comment on an issue
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/issues/{issueNumber}/comments", jsonBody)
  return fromJson(resp.body, GiteaComment)

proc editIssueComment*(client: GiteaClient, owner: string, repo: string, commentId: int, payload: CreateCommentPayload): GiteaComment =
  ## Edit a comment
  let jsonBody = toJson(payload)
  let resp = client.patch(&"/repos/{owner}/{repo}/issues/comments/{commentId}", jsonBody)
  return fromJson(resp.body, GiteaComment)

proc deleteIssueComment*(client: GiteaClient, owner: string, repo: string, commentId: int) =
  ## Delete a comment
  discard client.delete(&"/repos/{owner}/{repo}/issues/comments/{commentId}")

# ===== LABEL API =====

proc listLabels*(client: GiteaClient, owner: string, repo: string): seq[GiteaLabel] =
  ## List all labels for a repository
  let resp = client.get(&"/repos/{owner}/{repo}/labels")
  return fromJson(resp.body, seq[GiteaLabel])

proc getLabel*(client: GiteaClient, owner: string, repo: string, labelId: int): GiteaLabel =
  ## Get a specific label
  let resp = client.get(&"/repos/{owner}/{repo}/labels/{labelId}")
  return fromJson(resp.body, GiteaLabel)

proc createLabel*(client: GiteaClient, owner: string, repo: string, payload: CreateLabelPayload): GiteaLabel =
  ## Create a new label
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/labels", jsonBody)
  return fromJson(resp.body, GiteaLabel)

proc editLabel*(client: GiteaClient, owner: string, repo: string, labelId: int, payload: EditLabelPayload): GiteaLabel =
  ## Edit a label
  let jsonBody = toJson(payload)
  let resp = client.patch(&"/repos/{owner}/{repo}/labels/{labelId}", jsonBody)
  return fromJson(resp.body, GiteaLabel)

proc deleteLabel*(client: GiteaClient, owner: string, repo: string, labelId: int) =
  ## Delete a label
  discard client.delete(&"/repos/{owner}/{repo}/labels/{labelId}")

# ===== MILESTONE API =====

proc listMilestones*(client: GiteaClient, owner: string, repo: string, 
                     state: string = "open", page: int = 1, limit: int = 10): seq[GiteaMilestone] =
  ## List milestones for a repository
  let resp = client.get(&"/repos/{owner}/{repo}/milestones?state={state}&page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaMilestone])

proc getMilestone*(client: GiteaClient, owner: string, repo: string, milestoneId: int): GiteaMilestone =
  ## Get a specific milestone
  let resp = client.get(&"/repos/{owner}/{repo}/milestones/{milestoneId}")
  return fromJson(resp.body, GiteaMilestone)

proc createMilestone*(client: GiteaClient, owner: string, repo: string, payload: CreateMilestonePayload): GiteaMilestone =
  ## Create a new milestone
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/milestones", jsonBody)
  return fromJson(resp.body, GiteaMilestone)

proc deleteMilestone*(client: GiteaClient, owner: string, repo: string, milestoneId: int) =
  ## Delete a milestone
  discard client.delete(&"/repos/{owner}/{repo}/milestones/{milestoneId}")

# ===== RELEASE API =====

proc listReleases*(client: GiteaClient, owner: string, repo: string, 
                  page: int = 1, limit: int = 10): seq[GiteaRelease] =
  ## List releases for a repository
  let resp = client.get(&"/repos/{owner}/{repo}/releases?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaRelease])

proc getRelease*(client: GiteaClient, owner: string, repo: string, releaseId: int): GiteaRelease =
  ## Get a specific release
  let resp = client.get(&"/repos/{owner}/{repo}/releases/{releaseId}")
  return fromJson(resp.body, GiteaRelease)

proc getReleaseByTag*(client: GiteaClient, owner: string, repo: string, tag: string): GiteaRelease =
  ## Get a release by tag name
  let resp = client.get(&"/repos/{owner}/{repo}/releases/tags/{tag}")
  return fromJson(resp.body, GiteaRelease)

proc getLatestRelease*(client: GiteaClient, owner: string, repo: string): GiteaRelease =
  ## Get the latest release
  let resp = client.get(&"/repos/{owner}/{repo}/releases/latest")
  return fromJson(resp.body, GiteaRelease)

# ===== ORGANIZATION API =====

proc listOrganizations*(client: GiteaClient, page: int = 1, limit: int = 10): seq[GiteaOrganization] =
  ## List organizations for the authenticated user
  let resp = client.get(&"/user/orgs?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaOrganization])

proc getOrganization*(client: GiteaClient, org: string): GiteaOrganization =
  ## Get an organization
  let resp = client.get(&"/orgs/{org}")
  return fromJson(resp.body, GiteaOrganization)

proc listOrganizationMembers*(client: GiteaClient, org: string, page: int = 1, limit: int = 10): seq[GiteaUser] =
  ## List members of an organization
  let resp = client.get(&"/orgs/{org}/members?page={page}&limit={limit}")
  return fromJson(resp.body, seq[GiteaUser])

# ===== UTILITY FUNCTIONS =====

proc `$`*(issue: GiteaIssue): string =
  ## Format an issue for display
  result = &"#{issue.number}: {issue.title}\n"
  result &= &"State: {issue.state}\n"
  result &= &"Author: {issue.user.login}\n"
  result &= &"Created: {issue.created_at}\n"
  
  if issue.labels.isSome and issue.labels.get().len > 0:
    result &= "Labels: "
    for i, label in issue.labels.get():
      if i > 0: result &= ", "
      result &= label.name
    result &= "\n"
  
  result &= &"URL: {issue.html_url}\n"
  
  if issue.body != "":
    result &= "\nDescription:\n"
    let bodyLines = issue.body.splitLines()
    for line in bodyLines:
      result &= "  " & line & "\n"
  
  result &= "\n" & "-".repeat(80) & "\n"

proc `$`*(pr: GiteaPullRequest): string =
  ## Format a pull request for display
  result = &"PR #{pr.number}: {pr.title}\n"
  result &= &"State: {pr.state}\n"
  result &= &"Author: {pr.user.login}\n"
  result &= &"Head: {pr.head.label} -> Base: {pr.base.label}\n"
  result &= &"Mergeable: {pr.mergeable}\n"
  result &= &"Merged: {pr.merged}\n"
  result &= &"Created: {pr.created_at}\n"
  
  if pr.labels.isSome and pr.labels.get().len > 0:
    result &= "Labels: "
    for i, label in pr.labels.get():
      if i > 0: result &= ", "
      result &= label.name
    result &= "\n"
  
  result &= &"URL: {pr.html_url}\n"
  
  if pr.body != "":
    result &= "\nDescription:\n"
    let bodyLines = pr.body.splitLines()
    for line in bodyLines:
      result &= "  " & line & "\n"
  
  result &= "\n" & "-".repeat(80) & "\n"