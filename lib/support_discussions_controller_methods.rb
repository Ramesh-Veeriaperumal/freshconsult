module SupportDiscussionsControllerMethods

  def toggle_monitor
    current_object = instance_variable_get(%{@#{controller_name.singularize}})
    @monitorship = current_object.monitorships.find_or_initialize_by_user_id(current_user.id)
    if @monitorship.new_record?
      @monitorship.portal_id = current_portal.id
      @monitorship.save
    else
      @monitorship.update_attributes(:active => !@monitorship.active, :portal_id => current_portal.id)
    end
    render :nothing => true
  end

  RESOURCE_NOT_FOUND_SETTINGS = {
    :post => {
      :notice =>  I18n.t('portal.post_not_found'),
      :js => "location.reload(true)",
      :html  => "<script>location.reload(true)</script>"
    },
    :topic => {
      :notice =>  I18n.t('portal.topic_not_found'),
      :js => "window.location.replace('/support/discussions')",
      :html  => "<script>window.location.replace('/support/discussions');</script>"
    }
  }

  def resource_not_found resource
    settings = RESOURCE_NOT_FOUND_SETTINGS[resource]
    if request.xhr?
      flash[:notice] = settings[:notice]
      respond_to do |format|
        format.html { render :text => settings[:html] }
        format.js { render :js => settings[:js] }
      end
    else
      if resource == :post
        raise(ActiveRecord::RecordNotFound)
      else
        flash[:notice] = I18n.t('portal.topic_not_found')
        redirect_to '/support/discussions'
      end
    end
  end

  def fetch_vote
    @vote = vote_parent.votes.find_or_initialize_by_user_id(current_user.id)
  end

  def toggle_vote
    @vote.new_record? ? create_vote : destroy_vote
    vote_parent.reload
  end

  def create_vote
    @vote.vote = true
    @vote.save
  end

  def destroy_vote
    @vote.destroy unless @vote.new_record?
  end

end
