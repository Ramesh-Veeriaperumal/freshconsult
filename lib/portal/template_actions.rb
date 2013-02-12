module Portal::TemplateActions
	
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
    session.delete(:preview_button)
    session.delete(:preview_url)    
  end
end