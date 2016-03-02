module Solution::ControllerMethods

	ACTION = {
		"create" => "new",
		"update" => "edit"
	}

	def self.included(base)
	  base.send :before_filter, :set_modal, :only => [:new, :edit]
	end

	def show_response meta, scope
		respond_to do |format|
      format.html {
        redirect_to solution_my_drafts_path('all') if meta.is_default?
      }
      format.xml  { render :xml => meta.to_xml(:include => scope) }
      format.json { render :json => meta.as_json(:include => scope) }
    end
	end

	def new_response object
		respond_to do |format|
      format.html { render :layout => false if @modal }
      format.xml  { render :xml => object }
    end
	end

	def edit_response meta, object
		respond_to do |format|
      if meta.is_default?
        flash[:notice] = I18n.t("#{short_name}_edit_not_allowed")
        redirect_to solution_my_drafts_path('all')
      else
        format.html { render  :layout => false if @modal }
      end
      format.xml  { render :xml => object }
    end
	end

  def set_modal
    @modal = true if request.xhr?
  end

	def post_response(meta, object)

    respond_to do |format|
      if meta.errors.blank?
      	reload_object
        format.html { html_response(meta, object) }
        format.js { js_response }
        format.xml  { render :xml => meta, :status => :created, :location => object }     
        format.json { render :json => meta, :status => :ok, :location => object }     
      else
        format.html { html_error_response }
        format.js { js_error_response }
        format.xml  { render :xml => meta.errors, :status => :unprocessable_entity }
        format.json  { render :json => meta.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy_response(url)
  	respond_to do |format|
      format.html {  redirect_to url }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  def reload_object
  	@article = @article.reload if short_name.eql?("article")
  end

  def html_response(meta, object)
  	case short_name.to_sym
			when :category
				redirect_to solution_category_path(meta)
			when :folder
				redirect_to solution_folder_path(meta)
			when :article
				flash[:notice] = flash_message if publish?
        redirect_to multilingual_article_path(object)
		end
  end

  def html_error_response
  	case short_name.to_sym
			when :category
				render :action => ACTION[params[:action]]
			when :folder
				set_customers_field if params[:action].eql?('update')
				render :action => ACTION[params[:action]]
			when :article
				if params[:action].eql?('create')
					render :action => ACTION[params[:action]]
				else
					render_edit
				end
		end
  end

  def js_response
  	case short_name.to_sym
			when :category, :folder
				render 'after_save', :formats => [:rjs]
			when :article
				flash[:notice] = t('solution.articles.prop_updated_msg') if params[:action].eql?('update')
		end
  end

  def js_error_response
  	case short_name.to_sym
			when :category, :folder
				render 'after_save', :formats => [:rjs]
			when :article
				if params[:action].eql?('update')
					flash[:notice] = t('solution.articles.prop_updated_error')
	        render 'update_error'
	      end
		end
  end

end