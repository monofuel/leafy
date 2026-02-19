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
  PageSize* = 50  # Gitea API maximum page size; used for internal pagination in list procs

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
    `ref`*: Option[string]

  EditIssuePayload* = ref object
    title*: Option[string]
    body*: Option[string]
    assignee*: Option[string]
    assignees*: Option[seq[string]]
    milestone*: Option[int]
    state*: Option[string]
    unset_due_date*: Option[bool]
    due_date*: Option[string]
    `ref`*: Option[string]

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
    reviewers*: Option[seq[string]]
    team_reviewers*: Option[seq[string]]

  EditPullRequestPayload* = ref object
    title*: Option[string]
    body*: Option[string]
    base*: Option[string]
    assignee*: Option[string]
    assignees*: Option[seq[string]]
    milestone*: Option[int]
    labels*: Option[seq[int]]
    state*: Option[string]
    due_date*: Option[string]
    allow_maintainer_edit*: Option[bool]

  CreateCommentPayload* = ref object
    body*: string

  CreateLabelPayload* = ref object
    name*: string
    color*: string
    description*: Option[string]
    exclusive*: Option[bool]
    is_archived*: Option[bool]

  EditLabelPayload* = ref object
    name*: Option[string]
    color*: Option[string]
    description*: Option[string]
    exclusive*: Option[bool]
    is_archived*: Option[bool]

  CreateMilestonePayload* = ref object
    title*: string
    description*: Option[string]
    due_on*: Option[string]
    state*: Option[string]

  AddLabelsPayload* = ref object
    labels*: seq[string]

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

  # Some endpoints (e.g. workflow dispatch) legitimately respond with 204 (No Content),
  # so we treat that as a successful response as well.
  if resp.code notin [200, 201, 204]:
    raise newException(GiteaError, &"Gitea API request failed: {resp.code} - {resp.body}")

  return resp

# ===== ACTIONS / WORKFLOWS API =====

proc dispatchWorkflow*(client: GiteaClient, owner: string, repo: string,
                       workflow: string, gitRef: string = "main",
                       inputs: Table[string, string] = initTable[string, string]()) =
  ## Trigger a GitHub-style actions workflow via the `workflow_dispatch` event.
  ##
  ## Args:
  ##   owner:   Repository owner.
  ##   repo:    Repository name.
  ##   workflow: The workflow identifier – either the numeric workflow ID or the
  ##             YAML file name (e.g. "build.yml").
  ##   gitRef:  The git reference (branch or tag) to use for the dispatch.
  ##   inputs:  Optional key/value inputs defined in the workflow file.

  var payload = %*{ "ref": gitRef }

  if inputs.len > 0:
    var inputsNode = %*{}
    for key, val in inputs:
      inputsNode[key] = %*val
    payload["inputs"] = inputsNode

  discard client.post(&"/repos/{owner}/{repo}/actions/workflows/{workflow}/dispatches", $payload)

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

proc searchUsers*(client: GiteaClient, query: string): seq[GiteaUser] =
  ## Search for users. Paginates internally and returns all matching results.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/users/search?q={query}&page={page}&limit={PageSize}")
    let data = fromJson(resp.body, JsonNode)
    let pageResults = fromJson($data["data"], seq[GiteaUser])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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

proc listUserRepositories*(client: GiteaClient, username: string): seq[GiteaRepository] =
  ## List all repositories for a user. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/users/{username}/repos?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaRepository])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

proc listCurrentUserRepositories*(client: GiteaClient): seq[GiteaRepository] =
  ## List all repositories for the authenticated user. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/user/repos?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaRepository])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

proc listOrganizationRepositories*(client: GiteaClient, org: string): seq[GiteaRepository] =
  ## List all repositories for an organization. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/orgs/{org}/repos?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaRepository])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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
                 state: string = "open",
                 labels: string = "", milestone: string = "", assignee: string = "",
                 q: string = "", `type`: string = "", milestones: string = "",
                 since: string = "", before: string = "",
                 created_by: string = "", assigned_by: string = "", mentioned_by: string = "",
                 sort: string = "", direction: string = ""): seq[GiteaIssue] =
  ## List all issues from a repository matching the filters. Paginates internally.
  ##
  ## Label filtering supports advanced syntax:
  ## - ``"bug,feature"`` — issues with both labels
  ## - ``"-bug"`` — exclude issues with "bug" label
  ## - ``"bug,-wontfix"`` — has "bug" but not "wontfix"
  ## - ``"0"`` — only unlabeled issues
  ##
  ## ``sort`` can be: oldest, recentupdate, leastupdate, mostcomment, leastcomment, priority.
  ## ``direction`` can be: asc, desc.
  result = @[]
  var pathBase = &"/repos/{owner}/{repo}/issues?state={state}"
  if labels != "":
    pathBase &= &"&labels={labels}"
  if milestone != "":
    pathBase &= &"&milestone={milestone}"
  if assignee != "":
    pathBase &= &"&assignee={assignee}"
  if q != "":
    pathBase &= &"&q={q}"
  if `type` != "":
    pathBase &= &"&type={`type`}"
  if milestones != "":
    pathBase &= &"&milestones={milestones}"
  if since != "":
    pathBase &= &"&since={since}"
  if before != "":
    pathBase &= &"&before={before}"
  if created_by != "":
    pathBase &= &"&created_by={created_by}"
  if assigned_by != "":
    pathBase &= &"&assigned_by={assigned_by}"
  if mentioned_by != "":
    pathBase &= &"&mentioned_by={mentioned_by}"
  if sort != "":
    pathBase &= &"&sort={sort}"
  if direction != "":
    pathBase &= &"&direction={direction}"
  var page = 1
  while true:
    let path = pathBase & &"&page={page}&limit={PageSize}"
    let resp = client.get(path)
    let pageResults = fromJson(resp.body, seq[GiteaIssue])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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

proc deleteIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int) =
  ## Delete an issue
  discard client.delete(&"/repos/{owner}/{repo}/issues/{issueNumber}")

# ===== PULL REQUEST API =====

proc listPullRequests*(client: GiteaClient, owner: string, repo: string,
                      state: string = "open",
                      base_branch: string = "", sort: string = "",
                      direction: string = "",
                      milestone: Option[int] = none(int),
                      labels: seq[int] = @[], poster: string = ""): seq[GiteaPullRequest] =
  ## List all pull requests from a repository matching the filters. Paginates internally.
  ##
  ## ``sort`` can be: oldest, recentupdate, leastupdate, mostcomment, leastcomment, priority.
  ## ``direction`` can be: asc, desc.
  result = @[]
  var pathBase = &"/repos/{owner}/{repo}/pulls?state={state}"
  if base_branch != "":
    pathBase &= &"&base_branch={base_branch}"
  if sort != "":
    pathBase &= &"&sort={sort}"
  if direction != "":
    pathBase &= &"&direction={direction}"
  if milestone.isSome:
    pathBase &= &"&milestone={milestone.get()}"
  if labels.len > 0:
    for labelId in labels:
      pathBase &= &"&labels={labelId}"
  if poster != "":
    pathBase &= &"&poster={poster}"
  var page = 1
  while true:
    let path = pathBase & &"&page={page}&limit={PageSize}"
    let resp = client.get(path)
    let pageResults = fromJson(resp.body, seq[GiteaPullRequest])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

proc getPullRequest*(client: GiteaClient, owner: string, repo: string, prNumber: int): GiteaPullRequest =
  ## Get a specific pull request
  let resp = client.get(&"/repos/{owner}/{repo}/pulls/{prNumber}")
  return fromJson(resp.body, GiteaPullRequest)

proc createPullRequest*(client: GiteaClient, owner: string, repo: string, payload: CreatePullRequestPayload): GiteaPullRequest =
  ## Create a new pull request
  let jsonBody = toJson(payload)
  let resp = client.post(&"/repos/{owner}/{repo}/pulls", jsonBody)
  return fromJson(resp.body, GiteaPullRequest)

proc editPullRequest*(client: GiteaClient, owner: string, repo: string, prNumber: int, payload: EditPullRequestPayload): GiteaPullRequest =
  ## Edit an existing pull request
  let jsonBody = toJson(payload)
  let resp = client.patch(&"/repos/{owner}/{repo}/pulls/{prNumber}", jsonBody)
  return fromJson(resp.body, GiteaPullRequest)

proc mergePullRequest*(client: GiteaClient, owner: string, repo: string, prNumber: int, 
                      mergeMethod: string = "merge", title: string = "", message: string = "",
                      deleteBranchAfterMerge: Option[bool] = none(bool),
                      forceMerge: Option[bool] = none(bool),
                      headCommitId: Option[string] = none(string),
                      mergeWhenChecksSucceed: Option[bool] = none(bool)) =
  ## Merge a pull request
  var payload = %*{
    "Do": mergeMethod,
    "MergeTitleField": title,
    "MergeMessageField": message
  }
  if deleteBranchAfterMerge.isSome:
    payload["delete_branch_after_merge"] = %deleteBranchAfterMerge.get()
  if forceMerge.isSome:
    payload["force_merge"] = %forceMerge.get()
  if headCommitId.isSome:
    payload["head_commit_id"] = %headCommitId.get()
  if mergeWhenChecksSucceed.isSome:
    payload["merge_when_checks_succeed"] = %mergeWhenChecksSucceed.get()
  discard client.post(&"/repos/{owner}/{repo}/pulls/{prNumber}/merge", $payload)

# ===== COMMENT API =====

proc listIssueComments*(client: GiteaClient, owner: string, repo: string, issueNumber: int,
                       since: string = "", before: string = ""): seq[GiteaComment] =
  ## List all comments for an issue. Paginates internally.
  result = @[]
  var pathBase = &"/repos/{owner}/{repo}/issues/{issueNumber}/comments"
  if since != "" or before != "":
    pathBase &= "?"
    if since != "":
      pathBase &= &"since={since}"
    if before != "":
      if since != "":
        pathBase &= "&"
      pathBase &= &"before={before}"
  var page = 1
  while true:
    let sep = if pathBase.contains('?'): "&" else: "?"
    let path = pathBase & &"{sep}page={page}&limit={PageSize}"
    let resp = client.get(path)
    let pageResults = fromJson(resp.body, seq[GiteaComment])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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
  ## List all labels for a repository. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/repos/{owner}/{repo}/labels?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaLabel])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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
  ## Delete a label. Raises GiteaError if deletion fails.
  discard client.delete(&"/repos/{owner}/{repo}/labels/{labelId}")

proc addLabelsToIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int, labels: seq[string]) =
  ## Add labels to an issue using the dedicated labels API
  let payload = AddLabelsPayload(labels: labels)
  let jsonBody = toJson(payload)
  discard client.post(&"/repos/{owner}/{repo}/issues/{issueNumber}/labels", jsonBody)

proc removeLabelFromIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int, labelId: int) =
  ## Remove a specific label from an issue using the label ID
  discard client.delete(&"/repos/{owner}/{repo}/issues/{issueNumber}/labels/{labelId}")

proc removeLabelsFromIssue*(client: GiteaClient, owner: string, repo: string, issueNumber: int, labelNames: seq[string]) =
  ## Remove specific labels from an issue by name
  if labelNames.len == 0:
    return
  
  # Get all labels in the repository to find IDs
  let allLabels = client.listLabels(owner, repo)
  
  # Remove each label by ID
  for labelName in labelNames:
    for repoLabel in allLabels:
      if repoLabel.name.toLowerAscii == labelName.toLowerAscii:
        client.removeLabelFromIssue(owner, repo, issueNumber, repoLabel.id)
        break

# ===== MILESTONE API =====

proc listMilestones*(client: GiteaClient, owner: string, repo: string,
                     state: string = "open", name: string = ""): seq[GiteaMilestone] =
  ## List all milestones for a repository. Paginates internally.
  result = @[]
  var pathBase = &"/repos/{owner}/{repo}/milestones?state={state}"
  if name != "":
    pathBase &= &"&name={name}"
  var page = 1
  while true:
    let path = pathBase & &"&page={page}&limit={PageSize}"
    let resp = client.get(path)
    let pageResults = fromJson(resp.body, seq[GiteaMilestone])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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
                  draft: Option[bool] = none(bool),
                  pre_release: Option[bool] = none(bool)): seq[GiteaRelease] =
  ## List all releases for a repository. Paginates internally.
  result = @[]
  var pathBase = &"/repos/{owner}/{repo}/releases"
  if draft.isSome or pre_release.isSome:
    pathBase &= "?"
    if draft.isSome:
      pathBase &= &"draft={draft.get()}"
    if pre_release.isSome:
      if draft.isSome:
        pathBase &= "&"
      pathBase &= &"pre-release={pre_release.get()}"
  var page = 1
  while true:
    let sep = if pathBase.contains('?'): "&" else: "?"
    let path = pathBase & &"{sep}page={page}&limit={PageSize}"
    let resp = client.get(path)
    let pageResults = fromJson(resp.body, seq[GiteaRelease])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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

proc listOrganizations*(client: GiteaClient): seq[GiteaOrganization] =
  ## List all organizations for the authenticated user. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/user/orgs?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaOrganization])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

proc getOrganization*(client: GiteaClient, org: string): GiteaOrganization =
  ## Get an organization
  let resp = client.get(&"/orgs/{org}")
  return fromJson(resp.body, GiteaOrganization)

proc listOrganizationMembers*(client: GiteaClient, org: string): seq[GiteaUser] =
  ## List all members of an organization. Paginates internally.
  result = @[]
  var page = 1
  while true:
    let resp = client.get(&"/orgs/{org}/members?page={page}&limit={PageSize}")
    let pageResults = fromJson(resp.body, seq[GiteaUser])
    if pageResults.len == 0:
      break
    result.add(pageResults)
    if pageResults.len < PageSize:
      break
    inc page

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
