module Api::ApplicationConcern
  extend ActiveSupport::Concern

  private

  def day_pass_expired_json
    @error = RequestError.new(:access_denied)
    render :template => '/request_error', :status => 403
  end

  def account_suspended_json
    @error = RequestError.new(:account_suspended)
    render :template => '/request_error', :status => 403
  end

  def unset_current_account
    Thread.current[:account] = nil
  end

  def unset_current_portal
    Thread.current[:portal] = nil
  end
  
  def check_account_state
    unless current_account.active? 
      respond_to do |format|
        account_suspended_hash = {:account_suspended => true}

        format.xml { render :xml => account_suspended_hash.to_xml }
        format.json { account_suspended_json }
        format.nmobile { render :json => account_suspended_hash.to_json }
        format.js { render :json => account_suspended_hash.to_json }
        format.widget { render :json => account_suspended_hash.to_json }
        format.html { 
          if privilege?(:manage_account)
            flash[:notice] = t('suspended_plan_info')
            return redirect_to(subscription_url)
          else
            flash[:notice] = t('suspended_plan_admin_info', :email => current_account.admin_email) 
            redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
          end
        }
      end
    end
  end
  
  def set_time_zone
    TimeZone.set_time_zone
  end
  
  # See http://stackoverflow.com/questions/8268778/rails-2-3-9-encoding-of-query-parameters
  # See https://rails.lighthouseapp.com/projects/8994/tickets/4807
  # See http://jasoncodes.com/posts/ruby19-rails2-encodings (thanks for the following code, Jason!)
  def force_utf8_params
    traverse = lambda do |object, block|
      if object.kind_of?(Hash)
        object.each_value { |o| traverse.call(o, block) }
      elsif object.kind_of?(Array)
        object.each { |o| traverse.call(o, block) }
      else
        block.call(object)
      end
      object
    end
    force_encoding = lambda do |o|
      RubyBridge.force_utf8_encoding(o)
    end
    traverse.call(params, force_encoding)
  end

  def api_request?
    request.cookies["_helpkit_session"]
  end

  def determine_pod
    shard = ShardMapping.lookup_with_domain(request.host)
    if shard.nil?
      return # fallback to the current pod.
    elsif shard.pod_info.blank?
      return # fallback to the current pod.
    elsif shard.pod_info != PodConfig['CURRENT_POD']
      Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
      redirect_to_pod(shard)
    end
  end

   def redirect_to_pod(shard)
    return if shard.nil?

    Rails.logger.error "Request URL: #{request.url}"
    # redirect to the correct POD using Nginx specific redirect headers.
    redirect_url = "/pod_redirect/#{shard.pod_info}" #Should match with the location directive in Nginx Proxy
    Rails.logger.error "Redirecting to the correct POD. Redirect URL is #{redirect_url}"
    response.headers["X-Accel-Redirect"] = redirect_url
    response.headers["X-Accel-Buffering"] = "off"

    redirect_to redirect_url
  end

  def set_current_account
    begin
      current_account.make_current
      User.current = current_user
    rescue ActiveRecord::RecordNotFound
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      handle_unverified_request
    end    
  end

  def select_shard(&block)
    Sharding.select_shard_of(request.host) do 
        yield 
    end
  end

  def handle_unverified_request
      super
      Rails.logger.error "CSRF TOKEN NOT SET #{params.inspect}"
      cookies.delete 'user_credentials'     
      current_user_session.destroy unless current_user_session.nil? 
      @current_user_session = @current_user = nil
      portal_redirect_url = root_url
      if params[:portal_type] == "facebook"
        portal_redirect_url = portal_redirect_url + "support/home"
      else
        portal_redirect_url = portal_redirect_url + "support/login"
      end
      respond_to do |format|
        format.html  {
          redirect_to portal_redirect_url
        }
        format.nmobile{
          render :json => {:logout => 'success'}.to_json
        }
        format.json{
          @error = RequestError.new(:unverified_request)
          render :template => '/request_error', :status => 401
        }
        format.widget{
          render :json => {:logout => 'success'}
        }
      end
  end

end
