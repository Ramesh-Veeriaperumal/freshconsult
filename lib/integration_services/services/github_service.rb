module IntegrationServices::Services
  class GithubService < IntegrationServices::Service
    include Redis::RedisKeys
    include Redis::IntegrationsRedis

    INTEGRATIONS_GITHUB_NOTIFICATION = "INTEGRATIONS_GITHUB_NOTIFY:%{account_id}:%{installed_application_id}:%{remote_integratable_id}:%{comment_url}"
    KEY_EXPIRE_TIME = 300

    LINK_ISSUE_FD_TEMPLATE = "Linked ticket to issue <a href='%{issue_link}'> \#%{issue} </a> in GitHub repository %{repo}"
    UNLINK_ISSUE_FD_TEMPLATE = "Unlinked ticket from issue <a href='%{issue_link}'> \#%{issue} </a> in GitHub repository %{repo}"
    LINK_ISSUE_GIT_TEMPLATE = "%{user_type} %{user} linked Freshdesk ticket <a href='%{ticket_url}'>%{ticket_id}</a> to this issue"
    UNLINK_ISSUE_GIT_TEMPLATE = "%{user_type} %{user} unlinked Freshdesk ticket <a href='%{ticket_url}'>%{ticket_id}</a> from this issue"
    COMMENT_TO_GITHUB = "Comment added by %{user_type} %{user} in Freshdesk ticket id <a href='%{ticket_url}'>%{ticket_id}</a>:<br/>%{comment}"
    COMMENT_TO_FRESHDESK = "<b> GitHub Repository : </b> %{repo}, <b>Issue ID :</b> <a href='%{issue_url}'>%{issue_id}</a> <br/><br/> %{comment}"
    CREATE_GITHUB_ISSUE = "Freshdesk Ticket ID: <a href='%{ticket_url}'>%{ticket_id}</a> <br/> " +
                          "Freshdesk Ticket Agent: %{agent_name}<br/>" +
                          "Freshdesk Ticket Agent Email: %{agent_email}<br/>" +
                          "Ticket Priority: %{ticket_priority}<br/>" +
                          "Freshdesk Ticket Description:%{description} <br/>"
    def self.title
      'GitHub'
    end

    def server_url
      self.configs["server_url"] || "https://api.github.com"
    end

    def receive_create_issue
      begin
        ticket = @installed_app.account.tickets.find(@payload[:local_integratable_id])
        if @configs["map_type_to_label"].to_bool
          @payload[:options][:labels] = ticket.ticket_type if(ticket.ticket_type.present?)
        end
        body = (CREATE_GITHUB_ISSUE % {
                  :description => ticket.description_with_attachments,
                  :agent_name => ticket.responder ? ticket.responder.name : "Unassigned",
                  :agent_email => ticket.responder ? ticket.responder.email : "Unavailable",
                  :ticket_priority => ticket.priority_name,
                  :ticket_id => ticket.display_id,
                  :ticket_url => ticket_url(ticket)
                }).html_safe
        issue = issue_resource.create(@payload[:title], body, @payload[:options])
        integrated_resource = link_issue_to_ticket(issue, ticket)
        add_fd_link_unlink_note "link", issue, integrated_resource
        if @installed_app.configs_freshdesk_comment_sync.to_bool
          options = {
            :operation => 'post_ticket_comments',
            :local_integratable_id => @payload[:local_integratable_id],
            :remote_integratable_id => "#{self.payload[:repository]}/issues/#{issue["number"].to_s}",
            :app_id => @installed_app.id,
          }
          Integrations::GithubWorker.perform_async(options)
        end
        return integrated_resource.attributes
      rescue RemoteError => e
        return error(e.to_s, e.status_code)
      end
    end

    def receive_issue
      begin
        issue = issue_resource.issue(@payload[:number])
        tracker_ticket = @installed_app.integrated_resources.first_integrated_resource("#{@payload[:repository]}/issues/#{@payload[:number]}").first.local_integratable
        issue["tracker_ticket"] = get_tracker_ticket_properties tracker_ticket
        return issue
      rescue RemoteError => e
        return error(e.to_s, e.status_code)
      end
    end

    def receive_link_issue
      begin
        @payload[:number] = @payload[:number].to_i.to_s
        issue = issue_resource.issue(@payload[:number])
        ticket = @installed_app.account.tickets.find(@payload[:local_integratable_id])
        integrated_resource_new = link_issue_to_ticket(issue, ticket)
        add_fd_link_unlink_note "link", issue, integrated_resource_new
        add_git_link_unlink_comment "link", integrated_resource_new
        return integrated_resource_new.attributes
      rescue RemoteError => e
        return error(e.to_s, e.status_code)
      end
    end

    def receive_unlink_issue
      begin
        integrated_resource = @installed_app.integrated_resources.find(@payload[:integrated_resource_id])
        @payload[:repository], @payload[:number] = get_issue_repo_and_id(integrated_resource)
        issue = issue_resource.issue(@payload[:number])
        add_fd_link_unlink_note "unlink", issue, integrated_resource
        add_git_link_unlink_comment "unlink", integrated_resource
        integrated_resource.destroy
        return {:message=> "Success"}
      rescue RemoteError => e
        return error(e.to_s, e.status_code)
      rescue Exception => e
        Rails.logger.error "Error unlinking the ticket from the github issue. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        return error("Error unlinking the ticket from the github issue")
      end
    end

    def receive_milestones
      begin
        repo_resource.list_milestones
      rescue IntegrationServices::Errors::RemoteError => e
        return error(e.to_s, e.status_code)
      end
    end

    def receive_repos
        repo_resource.list_repos
    end

    def receive_add_webhooks
      @installed_app.configs[:inputs]["webhooks"] ||= {}
      return if @payload[:events].blank?
      @payload[:repositories].each do |repo|
        resp = webhook_resource.create_webhook repo, 'web', {:url => @payload[:url] }, {:events => @payload[:events]}
        @installed_app.configs_webhooks[repo] = resp["id"]
      end
      @installed_app.save!
    end

    def receive_delete_webhooks
      @payload[:webhooks].each do |repo, id|
        webhook_resource.delete_webhook repo, id
      end
    end

    def receive_sync_comment_to_github
      note = @payload[:act_on_object]
      return unless @configs["freshdesk_comment_sync"].to_bool && note.external_note.nil?
      local_resource = @installed_app.integrated_resources.find_by_local_integratable_id(note.notable_id, @installed_app)
      return unless local_resource.present?
      remote_resource = @installed_app.integrated_resources.first_integrated_resource(local_resource.remote_integratable_id).first
      if( remote_resource.id == local_resource.id )
        @payload[:repository], issue_id = get_issue_repo_and_id(remote_resource)
        comment = (COMMENT_TO_GITHUB % {
                     :comment => note.liquidize_body,
                     :user => note.user.name,
                     :user_type => note.user.agent? ? "agent" : "customer",
                     :ticket_id => note.notable.display_id,
                     :ticket_url => ticket_url(note.notable)
                   }).html_safe
        issue_comment = issue_resource.add_comment(issue_id, comment)
        redis_key = get_redis_key(remote_resource, issue_comment["url"])
        set_integ_redis_key(redis_key, "true", KEY_EXPIRE_TIME)
      end
    end

    def receive_issue_comment_webhook
      remote_integratable_id = "#{@payload["repository"]["full_name"]}/issues/#{@payload["issue"]["number"]}"

      return unless @installed_app.configs_github_comment_sync.to_bool
      integrated_resource = @installed_app.integrated_resources.first_integrated_resource(remote_integratable_id).first
      return unless integrated_resource.present?
      comment = @payload["comment"]["body"]
      comment_url = @payload["comment"]["url"]
      comment.gsub!(/(?:\!\[.*?\]\((.*?)\))/, '<br/> \1 <br/>')
      redis_key = get_redis_key(integrated_resource, comment_url)
      redis_value = get_integ_redis_key(redis_key)
      return if redis_value

      user = get_user(@payload['comment']['user']['id'], @payload['comment']['user']['login'] )
      repo, issue_id = get_issue_repo_and_id(integrated_resource)
      body_html = (COMMENT_TO_FRESHDESK % {
                     :comment => comment,
                     :name => user.name,
                     :issue_id => issue_id,
                     :issue_url => @payload["issue"]["html_url"],
                     :repo => repo
                   }).html_safe
      options = {
        :external_id =>  @payload["comment"]["id"],
        :to_emails => integrated_resource.local_integratable.responder ? [integrated_resource.local_integratable.responder.email] : []
      }
      add_note_and_external_note(integrated_resource.local_integratable, user, body_html, options)
      return "Note Added Successfully", :ok

    end

    def receive_issues_webhook
      remote_integratable_id = "#{@payload["repository"]["full_name"]}/issues/#{@payload["issue"]["number"]}"
      return if @installed_app.configs_github_status_sync == "none"
      integrated_resource = @installed_app.integrated_resources.first_integrated_resource(remote_integratable_id).first
      if integrated_resource.present? && @payload["github"]["action"] == "closed"
        integrated_resource.local_integratable.update_ticket_attributes(:status => @installed_app.configs_github_status_sync)
        return "Status set to #{@installed_app.configs_github_status_sync}", :ok
      end
    end

    def receive_install
      installed_rule = Integrations::AppBusinessRule.find_by_installed_application_id( @installed_app.id )
      unless installed_rule.present?
        app_rule = VaRule.new(
          :rule_type => VAConfig::INSTALLED_APP_BUSINESS_RULE,
          :name => "git_comment_sync",
          :description => "This rule will update the github issue with the comment that was posted in the corresponding freshdesk ticket.",
          :match_type => "any",
          :filter_data => [
            {
              :name => "any",
              :operator => "is",
              :value => "any",
              :action_performed=>{
                :entity=>"Helpdesk::Note",
                :action=>:create
              }
            }
          ],
          :action_data => [
            { :name => "Integrations::IntegrationRulesHandler",
              :value => "execute",
              :service => "github",
              :event => "sync_comment_to_github",
              :include_va_rule => true
            }
          ],
          :active => true,
        )
        app_rule.account_id = @installed_app.account_id
        app_rule.build_app_business_rule(
          :application => @installed_app.application,
          :account_id => @installed_app.account_id,
          :installed_application => @installed_app
        )
        app_rule.save!
      end
    end

    def receive_uninstall
      @configs["webhooks"].each do |repo, id|
        webhook_resource.delete_webhook repo, id
      end
    end

    private

    def link_issue_to_ticket(issue, ticket)
      @installed_app.integrated_resources.create(
        :remote_integratable_id =>"#{self.payload[:repository]}/issues/#{issue["number"].to_s}",
        :account => @installed_app.account,
        :local_integratable => ticket
      )
    end

    def get_redis_key(resource, comment_url)
      INTEGRATIONS_GITHUB_NOTIFICATION % {
        :account_id=>@installed_app.account.id,
        :installed_application_id=> @installed_app.id,
        :remote_integratable_id=>resource.remote_integratable_id,
        :comment_url => comment_url
      }
    end

    def add_git_link_unlink_comment(type, integrated_resource)
      template_data = {
        :user => User.current.name,
        :user_type => User.current.agent? ? "Agent" : "Customer",
        :ticket_id => integrated_resource.local_integratable.display_id,
        :ticket_url => ticket_url(integrated_resource.local_integratable)
      }
      template = type == "link" ? LINK_ISSUE_GIT_TEMPLATE : UNLINK_ISSUE_GIT_TEMPLATE
      comment = (template % template_data).html_safe
      first_resource = @installed_app.integrated_resources.first_integrated_resource("#{@payload[:repository]}/issues/#{@payload[:number]}").first
      issue_comment = issue_resource.add_comment(@payload[:number], comment)
      redis_key = get_redis_key(first_resource, issue_comment["url"])
      set_integ_redis_key(redis_key, "true", KEY_EXPIRE_TIME)
    end

    def add_fd_link_unlink_note(type, issue, integrated_resource)
      template_data = {
        :repo => @payload[:repository],
        :issue => issue["number"],
        :issue_link => issue["html_url"],
      }
      template = type == "link" ? LINK_ISSUE_FD_TEMPLATE : UNLINK_ISSUE_FD_TEMPLATE
      note_body = (template % template_data).html_safe
      add_note_and_external_note integrated_resource.local_integratable, User.current, note_body
    end

    def get_user(remote_user_id, user_name)
      account = @installed_app.account
      user_credential = @installed_app.user_credentials.find_by_remote_user_id(remote_user_id)
      return user_credential.user if(user_credential.present?)
      user = nil
      begin
        user_hash = user_resource.get_user(user_name)
      rescue IntegrationServices::Errors::RemoteError
      end
      user = account.users.where("external_id = ?", "GitHub-#{remote_user_id}").first
      user = account.user_emails.user_for_email(user_hash["email"]) if user.nil? && user_hash["email"].present?
      if( user.nil? )
        user = account.contacts.new
        user.active = true
        result = user.signup!(
          :user => {
            :name => user_hash["name"] || user_name,
            :external_id => "GitHub-#{remote_user_id}",
            :email => user_hash["email"]
          }
        )
        raise ActiveRecord::RecordNotSaved, "Error in creating GitHub user" unless result
      end

      @installed_app.user_credentials.create(
        :user_id => user.id,
        :account_id => account.id,
        :remote_user_id => remote_user_id
      )
      user
    end

    def add_note_and_external_note(ticket, user, body_html, options = {})
      note_hash = {
        :private => true,
        :user_id => user.id,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        :account_id => @installed_app.account_id,
        :note_body_attributes => {
          :body_html => body_html,
        },
        :to_emails => options[:to_emails] || [],
      }
      note = ticket.notes.build(note_hash)
      note.build_external_note(:external_id => options[:external_id], :account_id => @installed_app.account_id, :installed_application_id => @installed_app.id)
      note.save_note
    end

    def error (msg, status = nil)
      web_meta[:status] = status || :not_found
      return {:message => msg}
    end

    def get_tracker_ticket_properties(tracker_ticket)
      {
        "id" => tracker_ticket.display_id,
        "link" => Rails.application.routes.url_helpers.helpdesk_ticket_path(tracker_ticket.display_id)
      }
    end

    def get_issue_repo_and_id(resource)
      resource.remote_integratable_id.split('/issues/')
    end

    def ticket_url(ticket)
      Rails.application.routes.url_helpers.helpdesk_ticket_url(ticket, :host => Account.current.host, :protocol => Account.current.url_protocol)
    end

    def repo_resource
      @repo_resource ||= IntegrationServices::Services::Github::GithubRepoResource.new(self)
    end

    def user_resource
      @user_resource ||= IntegrationServices::Services::Github::GithubUserResource.new(self)
    end

    def issue_resource
      @issue_resource ||= IntegrationServices::Services::Github::GithubIssueResource.new(self)
    end

    def webhook_resource
      @webhook_resource ||= IntegrationServices::Services::Github::GithubWebhookResource.new(self)
    end
  end
end
