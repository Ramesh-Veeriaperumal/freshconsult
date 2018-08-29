module Portal::TemplateActions
  include Redis::RedisKeys
  include Redis::PortalRedis
  include Portal::PreviewKeyTemplate
  include Portal::MintApplicableCheckActions
  
  # setting portal
  def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id])# || current_portal
  end

  def syntax_rescue
    yield
    rescue Exception => e
      flash[:error] = e.to_s
      respond_to do |format|
        format.html { 
          redirect_to support_home_path and return
        }
        format.js{ render "update.rjs" and return }
      end
  end

  # Liquid validation
  def liquid_syntax?(liquid_data)
    syntax_rescue { Liquid::Template.parse(liquid_data) }
  end

  # css validation
  def css_syntax?(custom_css)
    _options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, 
        :always_update => true, :style => :compact)
    _options[:load_paths] << "#{Rails.root}/public/src/portal"

    syntax_rescue { Sass::Engine.new("@import \"lib/settings\"; #{custom_css}", _options).render }
  end

  def clear_preview_session
    unset_preview
    unset_mint_preview
    remove_portal_redis_key(preview_url_key)
  end

  def unset_mint_preview
     remove_others_redis_key(mint_preview_key)
  end
  
  def set_mint_preview
     set_others_redis_key(mint_preview_key,true,300)
  end

  def unset_preview
     remove_portal_redis_key(is_preview_key)
  end

  def set_preview
    set_portal_redis_key(is_preview_key, true,300)
  end

  def set_preview_and_redirect(preview_url)
    unset_mint_preview
    set_preview
    set_portal_redis_key(preview_url_key, preview_url)
    if current_portal == @portal
      redirect_url = support_preview_path 
    else
      redirect_url = support_preview_url(:host => @portal.host)
    end
    redirect_to redirect_url and return
  end

  def is_preview_key
    IS_PREVIEW % { :account_id => current_account.id, 
      :user_id => User.current.id, :portal_id => scoper.id}
  end

  def remove_all_preview_redis_key(current_account,current_portal)
    agents = current_account.agents.preload(:user=>:user_roles)
    agents.each do |agent|
      roles = agent.user.user_roles
      roles.each do |role|
        if role.role_id == 1 || role.role_id = 2
          remove_others_redis_key(mint_preview_key_remove(current_account,agent,current_portal))
          remove_portal_redis_key(draft_key_remove(current_account,agent,current_portal))
          remove_portal_redis_key(is_preview_key_remove(current_account,agent,current_portal))
          break
        end
      end
    end
  end

  def is_preview_key_remove(current_account,agent,current_portal)
      IS_PREVIEW % { :account_id => current_account.id, 
        :user_id => agent.user_id, :portal_id => current_portal.id}
  end

  def mint_preview_key_remove(current_account,agent,current_portal)
      MINT_PREVIEW_KEY % { :account_id => current_account.id, 
                           :user_id => agent.user_id, 
                           :portal_id => current_portal.id}
  end

  def draft_key_remove(current_account,agent,current_portal,label = "cosmetic")
        PORTAL_PREVIEW % {:account_id => current_account.id,
                          :template_id => current_portal.template.id,
                          :label => label,
                          :user_id => agent.user_id }
  end

  def preview_url_key
    PREVIEW_URL % { :account_id => current_account.id, 
      :user_id => User.current.id, :portal_id => scoper.id}
  end
end