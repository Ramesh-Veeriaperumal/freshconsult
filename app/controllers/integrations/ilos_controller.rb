class Integrations::IlosController < ApplicationController
    
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :check_current_user, :only => [:get_recorder_token, :popupbox]
  before_filter :get_installed_app, :only => [:ticket_note, :forum_topic, :solution_article, :get_recorder_token]
  before_filter :verify_authenticity, :video_params, :only => [:ticket_note, :forum_topic, :solution_article]
  before_filter :get_params_body_hash, :only => [:get_recorder_token]
  
  SECRET_KEY = "8e3f3b00cb29d7c050c7856fe22f824ee66de9850c0e98b4f6cb6a2de5e22a86306dd71056151483817194282a2046c4b6a548122c8bff413e806b552c3ee647"

  def ticket_note
    video_url = params[:videoURL]
    note_link = @video_params['video_title']
    display_id = @video_params['resource_id']
    private_note = @video_params['private_note']
    incoming = @video_params['incoming'].to_bool
    note_desc_html = %Q{<div class='ilos_frame'>#{@note_desc}<br><br><a href='#{video_url}' class='video_link' target='blank'>#{note_link}</a><br><br>#{@iframe_html}</div>}
    @ticket = current_account.tickets.find_by_display_id(display_id)
    note = @ticket.notes.build(
        :private => private_note,
        :user => get_user,
        :account_id => current_account.id,
        :incoming => incoming,
        :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal],
        :note_body_attributes => { :body_html => note_desc_html }
    )
    if note.save_note!
      render :text => t('integrations.ilos.messages.ilos_success')
    else
      render :text => t('integrations.ilos.messages.ilos_error')
    end
  end

  def forum_topic
    topic_id = @video_params['resource_id']
    @topic = current_account.topics.find(topic_id)
    user = get_user
    note_desc_html = %Q{<div class='ilos_frame'><p>#{@note_desc}</p><br>#{@iframe_html}</div>}

    if user.agent?
      post = @topic.posts.build(
        :user => user,
        :account_id => current_account.id,
        :body_html => note_desc_html,
      )
      saved = post.save!
    else
      post = SQSPost.new({
        :user => { :id => user.id, :name => user.name, :email => user.email },
        :account_id => current_account.id,
        :body_html => note_desc_html,
        :topic => {:id => @topic.id },
        :attachments => {},
        :cloud_file_attachments => [],
        :request_params => @video_params[:request_params],
        :portal => current_portal.id
      })
      saved = post.save
    end

    if saved
      render :text => t('integrations.ilos.messages.ilos_success')
    else
      render :text => t('integrations.ilos.messages.ilos_error')
    end
  end

  def solution_article
    article_id = @video_params['resource_id']
    @article = current_account.solution_articles.find(article_id)
    @draft = @article.draft.presence || @article.create_draft_from_article
    get_user
    note_desc_html = %Q{<div class='ilos_frame'><p>#{@note_desc}</p><br>#{@iframe_html}</div>}
    @draft.description += note_desc_html
    if @draft.save! 
      render :text => t('integrations.ilos.messages.ilos_success')
    else
      render :text => t('integrations.ilos.messages.ilos_error')
    end
  end

  def get_recorder_token
    hrp = HttpRequestProxy.new
    req_params = {:user_agent => request.headers['HTTP_USER_AGENT'] }
    response = hrp.fetch_using_req_params(params,req_params)
    render response
  end

  def popupbox
    render :partial => integrations_ilos_popupbox_path, :locals => { :ilos_entity_id => params[:ilos_entity_id], :location => params[:location] } 
  end

  private

  def get_installed_app
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:ilos]).first
    render :json => {:error => "Application not installed"} and return unless installed_app
    @api_key = installed_app.configs[:inputs][:api_key]
  end

  def get_user
    user_id = @video_params['user_id']
    user = current_account.all_users.where(:deleted => false).find(user_id)
    user.make_current
    user
  end

  def video_params
    @video_params = params[:video_endpoint_extras]
    @iframe_html = handle_ilos_iframe
    @note_desc = @video_params['video_desc'].presence || t('integrations.ilos.messages.default_video_desc')
  end

  def handle_ilos_iframe
    nok_dom = Nokogiri::HTML::DocumentFragment.parse(params[:iframe])
    iframe_dom = nok_dom.at_css "iframe"
    iframe_dom.attributes['width'].value = '580px'
    iframe_dom.attributes['height'].value = '340px'
    nok_dom.to_html
  end

  def get_params_body_hash
    timestamp = Time.now.to_i
    parsed_body = JSON.parse(params[:body])
    resource_id = parsed_body['video_endpoint_extras']['resource_id']
    user_id = parsed_body['video_endpoint_extras']['user_id']
    secret_token = generate_secret_token(timestamp, resource_id, user_id)
    parsed_body['video_endpoint_extras']['secret_token'] = secret_token
    parsed_body['video_endpoint_extras']['timestamp'] = timestamp
    parsed_body['video_endpoint_extras']['request_params'] = post_request_params if parsed_body['video_endpoint_extras']['user_location'] == "portal_forum"
    parsed_body['api_key'] = @api_key
    params[:body] = parsed_body
  end

  def post_request_params
    {
      :request_params => {
        :user_ip => request.remote_ip,
        :referrer => request.referrer,
        :user_agent => request.env['HTTP_USER_AGENT']
      }
    }
  end

  def verify_authenticity
    timestamp = params[:video_endpoint_extras][:timestamp]
    resource_id = params[:video_endpoint_extras][:resource_id]
    user_id = params[:video_endpoint_extras][:user_id]
    secret_token = generate_secret_token(timestamp, resource_id, user_id)
    if !Rack::Utils.secure_compare(params[:video_endpoint_extras][:secret_token], secret_token)
      render :json => {:error => "Authentication failed!!!"} and return
    end
  end

  def generate_secret_token(timestamp, resource_id, user_id)
    digest  = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, SECRET_KEY, (@api_key + timestamp.to_s + resource_id.to_s + user_id.to_s ))
  end

  def check_current_user
    render :status => :unauthorized if current_user.blank?
  end
end
