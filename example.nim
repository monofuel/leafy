import
  std/[os, strformat, options],
  src/leafy

## Example usage of the Gitea API client library

proc main() =
  # Initialize client - automatically uses GITEA_TOKEN environment variable
  let baseUrl = getEnv("GITEA_URL", "https://gitea.example.com")
  let token = getEnv("GITEA_TOKEN", "")
  
  echo "Creating Gitea client for: ", baseUrl
  # Client will automatically use GITEA_TOKEN if available
  let client = newGiteaClient(baseUrl)
  defer: client.close()
  
  try:
    # Example 1: Get current user (requires authentication)
    if token != "":
      echo "\n=== Current User ==="
      let currentUser = client.getCurrentUser()
      echo &"Username: {currentUser.login}"
      echo &"Full name: {currentUser.full_name}"
      echo &"Email: {currentUser.email}"
    
    # Example 2: Get a public repository
    echo "\n=== Repository Info ==="
    let owner = "monofuel"
    let repo = "leafy"
    
    if client.checkRepository(owner, repo):
      let repository = client.getRepository(owner, repo)
      echo &"Repository: {repository.full_name}"
      echo &"Description: {repository.description}"
      echo &"Stars: {repository.stars_count}"
      echo &"Forks: {repository.forks_count}"
      echo &"Language: {repository.language}"
      echo &"URL: {repository.html_url}"
      
      # Example 3: List issues
      echo "\n=== Issues ==="
      let issues = client.listIssues(owner, repo, "open", page=1, limit=5)
      if issues.len > 0:
        echo &"Found {issues.len} open issues:"
        for issue in issues:
          echo &"  #{issue.number}: {issue.title}"
          echo &"    Author: {issue.user.login}"
          echo &"    Created: {issue.created_at}"
          if issue.labels.len > 0:
            echo "    Labels: "
            for label in issue.labels:
              echo &"      - {label.name} ({label.color})"
          echo ""
          
          # You can also use the $ operator for full formatting:
          # echo $issue
      else:
        echo "No open issues found."
      
      # Example 4: List pull requests
      echo "\n=== Pull Requests ==="
      let prs = client.listPullRequests(owner, repo, "open", page=1, limit=5)
      if prs.len > 0:
        echo &"Found {prs.len} open pull requests:"
        for pr in prs:
          echo &"  PR #{pr.number}: {pr.title}"
          echo &"    Author: {pr.user.login}"
          echo &"    {pr.head.label} -> {pr.base.label}"
          echo &"    Mergeable: {pr.mergeable}"
          echo ""
          
          # You can also use the $ operator for full formatting:
          # echo $pr
      else:
        echo "No open pull requests found."
      
      # Example 5: List repository labels
      echo "\n=== Labels ==="
      let labels = client.listLabels(owner, repo)
      if labels.len > 0:
        echo &"Found {labels.len} labels:"
        for label in labels:
          echo &"  - {label.name} (#{label.color}): {label.description}"
      else:
        echo "No labels found."
      
    else:
      echo &"Repository {owner}/{repo} not found or not accessible."
    
    # Example 6: Create an issue (requires authentication and write access)
    if token != "":
      echo "\n=== Creating Issue (example) ==="
      echo "Note: This is commented out to avoid creating test issues"
      echo "Uncomment the following code to actually create an issue:"
      echo """
      let createPayload = CreateIssuePayload(
        title: "Test issue from Leafy",
        body: option("This is a test issue created using the Leafy Gitea API client."),
        labels: option(@[1]) # Assuming label ID 1 exists
      )
      let newIssue = client.createIssue(owner, repo, createPayload)
      echo &"Created issue #{newIssue.number}: {newIssue.title}"
      """
    
  except GiteaError as e:
    echo "Gitea API error: ", e.msg
  except Exception as e:
    echo "Error: ", e.msg

when isMainModule:
  main() 