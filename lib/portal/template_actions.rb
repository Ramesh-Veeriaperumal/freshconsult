module Portal::TemplateActions
	
	# setting portal
	def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id])# || current_portal
  end

  # setting forum builder
  def set_forum_builder
    ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
  end

  # Liquid validation
  def liquid_syntax?(liquid_data)
    begin
      Liquid::Template.parse(liquid_data)
    rescue Exception => e
      flash[:error] = e.to_s
      respond_to do |format|
        format.html { 
          redirect_to support_home_path and return
        }
        format.js{ render "update.rjs" and return }
      end
      #NewRelic::Agent.notice_error(e)
    end  
  end

  # css validation
  def css_syntax?(custom_css)
    begin
      _options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, 
        :always_update => true, :style => :compact)
      custom_css = Sass::Engine.new(custom_css, _options).render
    rescue Exception => e
      first_line = e.backtrace[0]
      flash[:error] = "#{e.to_s} at line number #{first_line[first_line.index(":")..-1]}"
      respond_to do |format|
        format.html { 
          redirect_to support_home_path and return
        }
        format.js{ render "update.rjs" and return }
      end
    end
  end

  def clear_preview_session
    session.delete(:preview_button)
  end
end