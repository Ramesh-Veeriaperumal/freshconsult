module Portal::TemplateActions
  include Redis::RedisKeys
  include Redis::PortalRedis
	
	# setting portal
	def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id])# || current_portal
  end

  # setting forum builder
  def set_forum_builder
    ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
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
    _options[:load_paths] << "#{RAILS_ROOT}/public/src/portal"

    syntax_rescue { Sass::Engine.new("@import \"lib/settings\"; #{custom_css}", _options).render }
  end

  def clear_preview_session
    remove_portal_redis_key(is_preview_key)
    remove_portal_redis_key(preview_url_key)
  end

  def set_preview_and_redirect(preview_url)
    set_portal_redis_key(is_preview_key, true)
    set_portal_redis_key(preview_url_key, preview_url)
    redirect_url = support_preview_url
    redirect_url = support_preview_url(:host => @portal.portal_url) unless @portal.portal_url.blank?
    Rails.logger.debug "::::#{redirect_url}"
    redirect_to redirect_url and return
  end

  def is_preview_key
    IS_PREVIEW % { :account_id => current_account.id, 
      :user_id => User.current.id, :portal_id => scoper.id}
  end

  def preview_url_key
    PREVIEW_URL % { :account_id => current_account.id, 
      :user_id => User.current.id, :portal_id => scoper.id}
  end
end