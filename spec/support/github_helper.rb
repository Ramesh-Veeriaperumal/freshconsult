module GithubHelper
  INTEGRATIONS_GITHUB_NOTIFICATION = "INTEGRATIONS_GITHUB_NOTIFY:%{account_id}:%{installed_application_id}:%{remote_integratable_id}:%{comment_url}"
  KEY_EXPIRE_TIME = 300
  def issue_comment_webhook_payload
    return {"action"=>"created", "issue"=>{"url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/2", "labels_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/2/labels{/name}", "comments_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/2/comments", "events_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/2/events", "html_url"=>"https://github.com/orgshreyas2/test1/issues/2", "id"=>88363617, "number"=>2, "title"=>"sdadaf", "user"=>{"login"=>"testshreyas234", "id"=>12845565, "avatar_url"=>"https://avatars.githubusercontent.com/u/12845565?v=3", "gravatar_id"=>"", "url"=>"https://api.github.com/users/testshreyas234", "html_url"=>"https://github.com/testshreyas234", "followers_url"=>"https://api.github.com/users/testshreyas234/followers", "following_url"=>"https://api.github.com/users/testshreyas234/following{/other_user}", "gists_url"=>"https://api.github.com/users/testshreyas234/gists{/gist_id}", "starred_url"=>"https://api.github.com/users/testshreyas234/starred{/owner}{/repo}", "subscriptions_url"=>"https://api.github.com/users/testshreyas234/subscriptions", "organizations_url"=>"https://api.github.com/users/testshreyas234/orgs", "repos_url"=>"https://api.github.com/users/testshreyas234/repos", "events_url"=>"https://api.github.com/users/testshreyas234/events{/privacy}", "received_events_url"=>"https://api.github.com/users/testshreyas234/received_events", "type"=>"User", "site_admin"=>false}, "labels"=>[], "state"=>"open", "locked"=>false, "assignee"=>nil, "milestone"=>nil, "comments"=>16, "created_at"=>"2015-06-15T09:01:14Z", "updated_at"=>"2015-09-02T19:50:09Z", "closed_at"=>nil, "body"=>"  Freshdesk Ticket # 6 - <div>sdgsfsf</div>\n\n "}, "comment"=>{"url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/comments/137225130", "html_url"=>"https://github.com/orgshreyas2/test1/issues/2#issuecomment-137225130", "issue_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/2", "id"=>137225130, "user"=>{"login"=>"shreyasns", "id"=>11406399, "avatar_url"=>"https://avatars.githubusercontent.com/u/11406399?v=3", "gravatar_id"=>"", "url"=>"https://api.github.com/users/shreyasns", "html_url"=>"https://github.com/shreyasns", "followers_url"=>"https://api.github.com/users/shreyasns/followers", "following_url"=>"https://api.github.com/users/shreyasns/following{/other_user}", "gists_url"=>"https://api.github.com/users/shreyasns/gists{/gist_id}", "starred_url"=>"https://api.github.com/users/shreyasns/starred{/owner}{/repo}", "subscriptions_url"=>"https://api.github.com/users/shreyasns/subscriptions", "organizations_url"=>"https://api.github.com/users/shreyasns/orgs", "repos_url"=>"https://api.github.com/users/shreyasns/repos", "events_url"=>"https://api.github.com/users/shreyasns/events{/privacy}", "received_events_url"=>"https://api.github.com/users/shreyasns/received_events", "type"=>"User", "site_admin"=>false}, "created_at"=>"2015-09-02T19:50:09Z", "updated_at"=>"2015-09-02T19:50:09Z", "body"=>"asdad"}, "repository"=>{"id"=>37260963, "name"=>"test1", "full_name"=>"orgshreyas2/test1", "owner"=>{"login"=>"orgshreyas2", "id"=>12845577, "avatar_url"=>"https://avatars.githubusercontent.com/u/12845577?v=3", "gravatar_id"=>"", "url"=>"https://api.github.com/users/orgshreyas2", "html_url"=>"https://github.com/orgshreyas2", "followers_url"=>"https://api.github.com/users/orgshreyas2/followers", "following_url"=>"https://api.github.com/users/orgshreyas2/following{/other_user}", "gists_url"=>"https://api.github.com/users/orgshreyas2/gists{/gist_id}", "starred_url"=>"https://api.github.com/users/orgshreyas2/starred{/owner}{/repo}", "subscriptions_url"=>"https://api.github.com/users/orgshreyas2/subscriptions", "organizations_url"=>"https://api.github.com/users/orgshreyas2/orgs", "repos_url"=>"https://api.github.com/users/orgshreyas2/repos", "events_url"=>"https://api.github.com/users/orgshreyas2/events{/privacy}", "received_events_url"=>"https://api.github.com/users/orgshreyas2/received_events", "type"=>"Organization", "site_admin"=>false}, "private"=>false, "html_url"=>"https://github.com/orgshreyas2/test1", "description"=>"", "fork"=>false, "url"=>"https://api.github.com/repos/orgshreyas2/test1", "forks_url"=>"https://api.github.com/repos/orgshreyas2/test1/forks", "keys_url"=>"https://api.github.com/repos/orgshreyas2/test1/keys{/key_id}", "collaborators_url"=>"https://api.github.com/repos/orgshreyas2/test1/collaborators{/collaborator}", "teams_url"=>"https://api.github.com/repos/orgshreyas2/test1/teams", "hooks_url"=>"https://api.github.com/repos/orgshreyas2/test1/hooks", "issue_events_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/events{/number}", "events_url"=>"https://api.github.com/repos/orgshreyas2/test1/events", "assignees_url"=>"https://api.github.com/repos/orgshreyas2/test1/assignees{/user}", "branches_url"=>"https://api.github.com/repos/orgshreyas2/test1/branches{/branch}", "tags_url"=>"https://api.github.com/repos/orgshreyas2/test1/tags", "blobs_url"=>"https://api.github.com/repos/orgshreyas2/test1/git/blobs{/sha}", "git_tags_url"=>"https://api.github.com/repos/orgshreyas2/test1/git/tags{/sha}", "git_refs_url"=>"https://api.github.com/repos/orgshreyas2/test1/git/refs{/sha}", "trees_url"=>"https://api.github.com/repos/orgshreyas2/test1/git/trees{/sha}", "statuses_url"=>"https://api.github.com/repos/orgshreyas2/test1/statuses/{sha}", "languages_url"=>"https://api.github.com/repos/orgshreyas2/test1/languages", "stargazers_url"=>"https://api.github.com/repos/orgshreyas2/test1/stargazers", "contributors_url"=>"https://api.github.com/repos/orgshreyas2/test1/contributors", "subscribers_url"=>"https://api.github.com/repos/orgshreyas2/test1/subscribers", "subscription_url"=>"https://api.github.com/repos/orgshreyas2/test1/subscription", "commits_url"=>"https://api.github.com/repos/orgshreyas2/test1/commits{/sha}", "git_commits_url"=>"https://api.github.com/repos/orgshreyas2/test1/git/commits{/sha}", "comments_url"=>"https://api.github.com/repos/orgshreyas2/test1/comments{/number}", "issue_comment_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues/comments{/number}", "contents_url"=>"https://api.github.com/repos/orgshreyas2/test1/contents/{+path}", "compare_url"=>"https://api.github.com/repos/orgshreyas2/test1/compare/{base}...{head}", "merges_url"=>"https://api.github.com/repos/orgshreyas2/test1/merges", "archive_url"=>"https://api.github.com/repos/orgshreyas2/test1/{archive_format}{/ref}", "downloads_url"=>"https://api.github.com/repos/orgshreyas2/test1/downloads", "issues_url"=>"https://api.github.com/repos/orgshreyas2/test1/issues{/number}", "pulls_url"=>"https://api.github.com/repos/orgshreyas2/test1/pulls{/number}", "milestones_url"=>"https://api.github.com/repos/orgshreyas2/test1/milestones{/number}", "notifications_url"=>"https://api.github.com/repos/orgshreyas2/test1/notifications{?since,all,participating}", "labels_url"=>"https://api.github.com/repos/orgshreyas2/test1/labels{/name}", "releases_url"=>"https://api.github.com/repos/orgshreyas2/test1/releases{/id}", "created_at"=>"2015-06-11T12:55:31Z", "updated_at"=>"2015-06-11T12:55:31Z", "pushed_at"=>"2015-06-11T12:55:31Z", "git_url"=>"git://github.com/orgshreyas2/test1.git", "ssh_url"=>"git@github.com:orgshreyas2/test1.git", "clone_url"=>"https://github.com/orgshreyas2/test1.git", "svn_url"=>"https://github.com/orgshreyas2/test1", "homepage"=>nil, "size"=>120, "stargazers_count"=>0, "watchers_count"=>0, "language"=>nil, "has_issues"=>true, "has_downloads"=>true, "has_wiki"=>true, "has_pages"=>false, "forks_count"=>0, "mirror_url"=>nil, "open_issues_count"=>61, "forks"=>0, "open_issues"=>61, "watchers"=>0, "default_branch"=>"master"}, "organization"=>{"login"=>"orgshreyas2", "id"=>12845577, "url"=>"https://api.github.com/orgs/orgshreyas2", "repos_url"=>"https://api.github.com/orgs/orgshreyas2/repos", "events_url"=>"https://api.github.com/orgs/orgshreyas2/events", "members_url"=>"https://api.github.com/orgs/orgshreyas2/members{/member}", "public_members_url"=>"https://api.github.com/orgs/orgshreyas2/public_members{/member}", "avatar_url"=>"https://avatars.githubusercontent.com/u/12845577?v=3", "description"=>nil}, "sender"=>{"login"=>"shreyasns", "id"=>11406399, "avatar_url"=>"https://avatars.githubusercontent.com/u/11406399?v=3", "gravatar_id"=>"", "url"=>"https://api.github.com/users/shreyasns", "html_url"=>"https://github.com/shreyasns", "followers_url"=>"https://api.github.com/users/shreyasns/followers", "following_url"=>"https://api.github.com/users/shreyasns/following{/other_user}", "gists_url"=>"https://api.github.com/users/shreyasns/gists{/gist_id}", "starred_url"=>"https://api.github.com/users/shreyasns/starred{/owner}{/repo}", "subscriptions_url"=>"https://api.github.com/users/shreyasns/subscriptions", "organizations_url"=>"https://api.github.com/users/shreyasns/orgs", "repos_url"=>"https://api.github.com/users/shreyasns/repos", "events_url"=>"https://api.github.com/users/shreyasns/events{/privacy}", "received_events_url"=>"https://api.github.com/users/shreyasns/received_events", "type"=>"User", "site_admin"=>false}}
  end

  def issue_comment_webhook_payload2
    return {
      "action"=> "created",
      "issue"=> {
        "id"=> 73464126,
        "number"=> 2,
        "title"=> "Spelling error in the README file",

      },
      "comment"=> {
        "url"=> "https=>//api.github.com/repos/baxterthehacker/public-repo/issues/comments/99262140",
        "id"=> 99262140,
        "user"=> {
          "login"=> "baxterthehacker",
          "id"=> 6752317,
          "type"=> "User",
          "site_admin"=> false
        },
        "created_at"=> "2015-05-05T23=>40=>28Z",
        "updated_at"=> "2015-05-05T23=>40=>28Z",
        "body"=> "You are totally right! I'll get this fixed right away."
      },
      "repository"=> {
        "id"=> 35129377,
        "name"=> "public-repo",
        "full_name"=> "baxterthehacker/public-repo",
      }
    }
  end
  def list_repo_json
    [{
       "id" => 37260963,
       "name" => "test1",
       "full_name" => "orgshreyas2/test1",
       "owner" => {
         "login" => "orgshreyas2",
         "id" => 12845577,
         "site_admin" => false
       },
       "private" => false,
     },
     {
       "id" => 37260988,
       "name" => "test2",
       "full_name" => "orgshreyas2/test2",
       "owner" => {
         "login" => "orgshreyas2",
         "id" => 12845577,
         "type" => "Organization",
         "site_admin" => false
       },
       "private" => false,
     }
    ]
  end
  def webhook_payload
    return { "action" => "created" }
  end

  def issue_payload
    return {
      "id"=> 1,
      "url"=> "https=>//api.github.com/repos/octocat/Hello-World/issues/1347",
      "number"=> 1347,
      "state"=> "open",
      "title"=> "Found a bug",
      "body"=> "I'm having a problem with this.",
      "user"=> {
        "login"=> "octocat",
        "id"=> 1,
        "type"=> "User",
        "site_admin"=> false
      },
      "labels"=> [
        {
          "url"=> "https=>//api.github.com/repos/octocat/Hello-World/labels/bug",
          "name"=> "bug",
          "color"=> "f29513"
        }
      ],
      "assignee"=> {
        "login"=> "octocat",
        "id"=> 1,
        "type"=> "User",
        "site_admin"=> false
      },
      "milestone"=> {
        "id"=> 1002604,
        "number"=> 1,
        "state"=> "open",
        "title"=> "v1.0",
        "description"=> "Tracking milestone for version 1.0",
        "due_on"=> "2012-10-09T23:39:01Z"
      },
    }
  end

  def comment_payload
    return {
      "id"=> 1,
      "url"=> "https=>//api.github.com/repos/octocat/Hello-World/issues/comments/1",
      "html_url"=> "https=>//github.com/octocat/Hello-World/issues/1347#issuecomment-1",
      "body"=> "Me too",
      "user"=> {
        "login"=> "octocat",
        "id"=> 1,
        "type"=> "User",
        "site_admin"=> false
      },
      "created_at"=> "2011-04-14T16:00:49Z",
      "updated_at"=> "2011-04-14T16:00:49Z"
    }
  end

  def user_payload
    return {
      "login"=> "octocat",
      "id"=> 1,
      "avatar_url"=> "https=>//github.com/images/error/octocat_happy.gif",
      "gravatar_id"=> "",
      "url"=> "https=>//api.github.com/users/octocat",
      "type"=> "User",
      "site_admin"=> false,
      "name"=> "monalisa octocat",
      "company"=> "GitHub",
      "blog"=> "https=>//github.com/blog",
      "location"=> "San Francisco",
      "email"=> "octocat@github.com",
      "hireable"=> false,
      "bio"=> "There once was...",
      "public_repos"=> 2,
      "public_gists"=> 1,
      "followers"=> 20,
      "following"=> 0,
    }
  end

  def list_milestones_payload
    return [
      {
        "url"=> "https=>//api.github.com/repos/octocat/Hello-World/milestones/1",
        "id"=> 1002604,
        "number"=> 1,
        "state"=> "open",
        "title"=> "v1.0",
        "description"=> "Tracking milestone for version 1.0",
        "due_on"=> "2012-10-09T23:39:01Z"
      },
    ]
  end

  def issue_event_payload(repo,issue, status = "closed")
    return {
      "github" => { "action"=> status },
      "issue"=> {

        "id"=> 73464126,
        "number"=> issue,
        "title"=> "Spelling error in the README file",
      },
      "repository"=> {
        "id"=> 35129377,
        "full_name"=> repo
      },
    }
  end

  def get_github_redis_key(resource, comment_url)
    INTEGRATIONS_GITHUB_NOTIFICATION % {
      :account_id=>@installed_app.account.id,
      :installed_application_id=> @installed_app.id,
      :remote_integratable_id=>resource.remote_integratable_id,
      :comment_url => comment_url
      }
  end

  def get_oauth_token
    return "588b218df3410472dd96425f411627b8e5d20ea9"
  end
end

