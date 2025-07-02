import
  std/[unittest, options, os, strformat, sequtils, strutils],
  ../src/leafy

## Integration tests for the Leafy Gitea API client library
## These tests connect to a real Gitea instance

const
  TestGiteaHost* = "192.168.90.12:3000"
  TestGiteaUrl* = "http://" & TestGiteaHost
  TestOwner* = "monofuel"
  TestRepo* = "leafy"
  TestIssueNumber* = 1

# Integration tests for actual Gitea instance
suite "Integration Tests - Repository":
  test "can check if repository exists":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let exists = client.checkRepository(TestOwner, TestRepo)
      check exists == true
      echo &"✅ Repository {TestOwner}/{TestRepo} exists"
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

  test "can get repository details":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let repo = client.getRepository(TestOwner, TestRepo)
      check repo.name == TestRepo
      check repo.owner.login == TestOwner
      check repo.full_name == &"{TestOwner}/{TestRepo}"
      
      echo &"✅ Repository details:"
      echo &"   Name: {repo.name}"
      echo &"   Full name: {repo.full_name}"
      echo &"   Description: {repo.description}"
      echo &"   Language: {repo.language}"
      echo &"   Stars: {repo.stars_count}"
      echo &"   Forks: {repo.forks_count}"
      echo &"   Default branch: {repo.default_branch}"
      echo &"   Created: {repo.created_at}"
      echo &"   HTML URL: {repo.html_url}"
      
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

  test "can list repository labels":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let labels = client.listLabels(TestOwner, TestRepo)
      echo &"✅ Found {labels.len} labels in repository:"
      for label in labels:
        echo &"   - {label.name} (#{label.color}): {label.description}"
        
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

suite "Integration Tests - Issues":
  test "can get specific issue":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let issue = client.getIssue(TestOwner, TestRepo, TestIssueNumber)
      check issue.number == TestIssueNumber
      
      echo &"✅ Issue #{issue.number} details:"
      echo &"   Title: {issue.title}"
      echo &"   State: {issue.state}"
      echo &"   Author: {issue.user.login}"
      echo &"   Created: {issue.created_at}"
      echo &"   Updated: {issue.updated_at}"
      echo &"   Comments: {issue.comments}"
      if issue.labels.isSome and issue.labels.get().len > 0:
        echo "   Labels:"
        for label in issue.labels.get():
          echo &"     - {label.name} ({label.color})"
      if issue.body != "":
        echo &"   Body: {issue.body[0..min(100, issue.body.len-1)]}..."
      echo &"   URL: {issue.html_url}"
      
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

  test "can list issues from repository":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let issues = client.listIssues(TestOwner, TestRepo, "open", page=1, limit=5)
      echo &"✅ Found {issues.len} open issues:"
      for issue in issues:
        echo &"   #{issue.number}: {issue.title}"
        echo &"     Author: {issue.user.login}, Created: {issue.created_at}"
        if issue.labels.isSome and issue.labels.get().len > 0:
          let labelNames = issue.labels.get().mapIt(it.name)
          echo "     Labels: " & labelNames.join(", ")
        
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

  test "can list issue comments":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let comments = client.listIssueComments(TestOwner, TestRepo, TestIssueNumber)
      echo &"✅ Found {comments.len} comments on issue #{TestIssueNumber}:"
      for comment in comments:
        echo &"   Comment #{comment.id} by {comment.user.login}:"
        echo &"     Created: {comment.created_at}"
        if comment.body.len > 100:
          echo &"     Body: {comment.body[0..97]}..."
        else:
          echo &"     Body: {comment.body}"
        echo &"     URL: {comment.html_url}"
        
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

suite "Integration Tests - Pull Requests":
  test "can list pull requests":
    let client = newGiteaClient(TestGiteaUrl)
    defer: client.close()
    
    try:
      let prs = client.listPullRequests(TestOwner, TestRepo, "open", page=1, limit=5)
      echo &"✅ Found {prs.len} open pull requests:"
      for pr in prs:
        echo &"   PR #{pr.number}: {pr.title}"
        echo &"     Author: {pr.user.login}"
        echo &"     {pr.head.label} -> {pr.base.label}"
        echo &"     Mergeable: {pr.mergeable}, Merged: {pr.merged}"
        echo &"     Created: {pr.created_at}"
        
    except GiteaError as e:
      echo &"❌ Gitea API error: {e.msg}"
      skip()
    except Exception as e:
      echo &"❌ Error: {e.msg}"
      skip()

echo "✅ Integration tests completed!"
echo &"   Tests connect to {TestGiteaUrl}/{TestOwner}/{TestRepo}"
echo &"   Run with: nim c -r tests/integration_test.nim" 