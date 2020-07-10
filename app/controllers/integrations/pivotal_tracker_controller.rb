class Integrations::PivotalTrackerController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:pivotal_updates]
  before_filter :check_app_installed?, :only => [:pivotal_updates, :update_config, :get_performer_email]

  include Integrations::PivotalTracker::Constant
  
  def tickets
    tkt = current_account.tickets.permissible(current_user)  
    @items = tkt.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 
    respond_to do |format|
      format.xml {
        render :xml => construct_xml
      }
    end
  end


  def pivotal_updates
    if @installed_app && @installed_app["configs"][:inputs]["pivotal_update"] == "1"
      pivotal_updates = JSON(request.raw_post)     
      primary_resources = pivotal_updates["primary_resources"].first
      story_id = primary_resources["id"]
      project_id = pivotal_updates["project"]["id"]
      performer_name = pivotal_updates["performed_by"]["name"]
      performer_id = pivotal_updates["performed_by"]["id"]
      case pivotal_updates["kind"].to_sym
        when :story_update_activity
          pivotal_values = pivotal_updates["changes"].find{|x| x["kind"] == PIVOTAL_STORY}
          changes = "<div> Story <a href=#{primary_resources["url"]} target=_blank > #{primary_resources["name"]}</a>
            updated with following changes:<br/><br/>"
          pivotal_values["original_values"].each do |key, value|
            if key == "deadline"
              value = Date.strptime((value.to_f / 1000).to_s, '%s') unless value == nil 
              pivotal_values["new_values"][key] = Date.strptime((pivotal_values["new_values"][key].to_f / 1000).to_s, '%s') unless pivotal_values["new_values"][key] == nil 
            end
            value = "none" if pivotal_values["original_values"][key] == nil
            pivotal_values["new_values"][key] = "none" if pivotal_values["new_values"][key] == nil
            changes += "#{key} changed from #{value} to #{pivotal_values["new_values"][key]} <br/>" unless EXCLUDE_ARR.include?(key)
          end
          changes = "<div>#{pivotal_updates["message"]} for the story <a href=#{primary_resources["url"]} target=_blank > #{primary_resources["name"]}</a>" if pivotal_updates["highlight"] == "rejected"
          changes += "</div>"
          add_note(project_id, story_id, changes, performer_id, performer_name) if changes.include? "changed from" or changes.include? "rejected"
        when :story_delete_activity
          pivotal_updates["primary_resources"].each do |resource|
            changes = "<div> story &quot;#{resource["name"]}&quot; deleted. </div>"
            add_note(project_id, resource["id"], changes, performer_id, performer_name)
            delete_integrated_resource(project_id, resource["id"])
          end
        when :story_move_into_project_activity
          pivotal_updates["primary_resources"].each do |resource|
            integrated_resource = Integrations::IntegratedResource.where(['remote_integratable_id LIKE ?', "%/stories/#{resource['id']}"]).first if integrated_resource.nil?
            integrated_resource["remote_integratable_id"] = "#{project_id}/stories/#{resource["id"]}"
            integrated_resource.save!
          end
        when :story_move_from_project_activity
          pivotal_updates["primary_resources"].each do |resource|
            changes = "<div> Story <a href=#{resource["url"]} target=_blank > #{resource["name"]}</a> moved from project 
            #{pivotal_updates["project"]["name"]}</div>" 
            add_note(project_id, resource["id"], changes, performer_id, performer_name)
            end
        when :task_create_activity, :task_update_activity, :comment_delete_activity, :comment_create_activity
          changes = "<div> #{pivotal_updates["message"]} for the story <a href=#{primary_resources["url"]} target=_blank > #{primary_resources["name"]}</a> </div>"
          add_note(project_id, story_id, changes, performer_id, performer_name)
        when :task_delete_activity
          changes = "<div> #{performer_name} deleted a task for the story <a href=#{primary_resources["url"]} target=_blank > #{primary_resources["name"]}</a> </div>"
          add_note(project_id, story_id, changes, performer_id, performer_name)
        else
          Rails.logger.debug "#{pivotal_updates["kind"]} case not handled"
      end
    end
    render :json => { :pivotal_message => "success"}
  end

  def update_config
    @installed_app["configs"][:inputs]["webhooks_applicationid"] = [] unless @installed_app["configs"][:inputs].include? "webhooks_applicationid"
    unless @installed_app["configs"][:inputs]["webhooks_applicationid"].include? params[:project_id] 
      @installed_app["configs"][:inputs]["webhooks_applicationid"].push(params[:project_id])
      @installed_app.save!
    end
    insert_integrated_resources
    note_msg = "<div>story <a href= #{params[:story_url]} target=_blank >#{params[:story_name]}</a> added to project
               #{params[:project_name]} as #{params[:story_type]} </div>"
    add_note(params[:project_id], params[:story_id], note_msg)
    render :json => { :pivotal_message => "success"}
  end

  private
    def construct_xml
      xml = ::Builder::XmlMarkup.new()
      xml.instruct!
      xml.external_stories(:type => "array") do 
        @items.each_with_index do |external_story|
          xml.external_story do
            xml.external_id(external_story["id"])
            xml.name(external_story["subject"])
            xml.description(external_story["description"])
            xml.requested_by(external_story.requester.name)
            xml.created_at(external_story["created_at"].strftime("%Y/%m/%d %H:%M:%S %Z"),:type => "datetime")
            xml.story_type("feature")
            xml.estimate(1, :type => "integer")
          end
        end
      end
    end


    def insert_integrated_resources
      ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
      resource = { "application_id" => params[:application_id], :integrated_resource => { :local_integratable_id => ticket.id,
                 :remote_integratable_id => "#{params[:project_id]}/stories/#{params[:story_id]}",
                 :local_integratable_type => "issue-tracking", :account => current_account }}
      result = Integrations::IntegratedResource.createResource(resource)
    end

    def delete_integrated_resource(project_id, story_id)
      remote_integratable_id = "#{project_id}/stories/#{story_id}"
      resource = { :integrated_resource => { "remote_integratable_id" => remote_integratable_id, :account => current_account}}
      Integrations::IntegratedResource.delete_resource_by_remote_integratable_id(resource)
    end

    def add_note(project_id, story_id, msg, performer_id=nil, performer_name =nil, project_flag=nil)
      remote_integratable_id = "#{project_id}/stories/#{story_id}"
      integrated_resource = Integrations::IntegratedResource.find_by_remote_integratable_id(remote_integratable_id) if project_flag.nil?
      integrated_resource = Integrations::IntegratedResource.where(['remote_integratable_id LIKE ?', "%/stories/#{story_id}"]).first if integrated_resource.nil?
      if current_user
        user_id = current_user.id
      else
        user = current_account.all_users.find_by_external_id("PT - #{performer_id}")
        user = current_account.users.find_by_email_or_name(get_performer_email(project_id, performer_id)) unless user
        user_id = get_user_id(user, performer_name, performer_id)
      end
      unless integrated_resource.nil?
        if integrated_resource.local_integratable_type == "Helpdesk::ArchiveTicket"
          archive_ticket = integrated_resource.local_integratable
          if archive_ticket
            @ticket = archive_ticket.ticket || create_ticket(archive_ticket)
            modify_integrated_resource(@ticket, integrated_resource)
          end      
        else
          @ticket = integrated_resource.local_integratable
        end
        note = @ticket.notes.build(
            :note_body_attributes => {:body_html => msg },
            :private => true,
            :source => current_account.helpdesk_sources.note_source_keys_by_token["note"],
            :account_id => current_account.id,
            :user_id => user_id
          )
        note.save_note
      end
    end

    def get_user_id(user,performer_name, performer_id)
     if user
        user[:external_id] = "PT - #{performer_id}"
        user.save!
        user_id = user.id
      else
        user_id = create_user(performer_name, performer_id).id
      end
    end

    def create_user(name, id)
      user = current_account.contacts.new
      user.signup!({ :user => { :name => name, :external_id => "PT - #{id}", :active => true, :helpdesk_agent => false }})
      user
    end

    def get_performer_email(project_id, user_id)
      hrp = HttpRequestProxy.new
      params = { :domain => "https://www.pivotaltracker.com", :ssl_enabled => true, :rest_url => "services/v5/projects/#{project_id}/memberships", 
                 :custom_auth_header => {"X-TrackerToken" => @installed_app.configs[:inputs]['api_key'] }}
      requestParams = { :method => "get", :user_agent => "_" }
      response = hrp.fetch_using_req_params(params, requestParams)
      json_parsed = JSON(response[:text])
      json_parsed.each do |obj|
        return obj["person"]["email"] if  obj["person"]["id"] == user_id
      end
    end

    def check_app_installed?
      @installed_app = current_account.installed_applications.with_name("pivotal_tracker").first
      return render :json => { :pivotal_message => "Application not installed"} if @installed_app.nil?
    end

    def modify_integrated_resource(ticket, integrated_resource)
      integrated_resource = Integrations::IntegratedResource.find(integrated_resource.id)
      integrated_resource.update_attributes({
          :local_integratable_type => "Helpdesk::Ticket", 
          :local_integratable_id => ticket.id 
        }) if integrated_resource
    end

    def create_ticket(archive_ticket)
      ticket = Helpdesk::Ticket.new(
                :requester_id => archive_ticket.requester_id,
                :subject => archive_ticket.subject,
                :ticket_body_attributes => { :description => archive_ticket.description })
      ticket.build_archive_child(:archive_ticket_id => archive_ticket.id) if archive_ticket
      ticket.save_ticket
      ticket
    end
end