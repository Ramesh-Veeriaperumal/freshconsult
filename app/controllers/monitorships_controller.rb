class MonitorshipsController < ApplicationController
  before_filter :access_denied, :unless => :logged_in?

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:toggle,:is_following]
  before_filter :unprocessable_entity, :unless => :valid_request
  before_filter :fetch_monitorship, :only => :toggle
  
  def toggle
    send(params[:type])
    respond_to do |format|
      format.html { 
                    assign_flash
                    redirect_to monitorable_object_path
                  }
      format.xml { head :ok }
      format.json { head :ok }
      format.js
    end
  end

  def is_following
    user_id = params[:user_id] || current_user.id
    @monitorship = Monitorship.find(:first, :conditions => { :user_id => user_id,:monitorable_id => params[:id],:monitorable_type =>params[:object].capitalize}) || []  
    respond_to do |format|
      format.xml { render :xml => @monitorship.to_xml(:except=>:account_id) }
      format.json { render :json => @monitorship.as_json(:except=>:account_id) }
    end
  end

  private

    def assign_flash
      flash[:notice] = t((@monitorship.active? ? 'monitorships.monitor_flash' : 'monitorships.non_monitor_flash'), :type => params[:object])
    end

    def monitorable_object_path
      if params[:object].include?("topic")
        return category_forum_topic_path(monitorable_object.forum.forum_category, monitorable_object.forum, monitorable_object.id)
      else
        return category_forum_path(monitorable_object.forum_category, monitorable_object.id)
      end
    end

    def valid_request
      monitorable? and valid_action?
    end

    def monitorable?
      Monitorship::ALLOWED_TYPES.include?(params[:object].to_sym) and monitorable_object
    end

    def monitorable_object
      @obj ||= params[:object].to_s.capitalize.constantize.find(params[:id])
    end

    def valid_action?
     Monitorship::ACTIONS.include?((params[:type] || params[:action]).to_sym)
    end

    def fetch_monitorship
      @monitorship = Monitorship.find_or_initialize_by_user_id_and_monitorable_id_and_monitorable_type(current_user.id, params[:id], params[:object].capitalize)
    end
    
    def follow
      @monitorship.update_attributes({:active => true, :portal_id => current_portal.id})
    end

    def unfollow
      @monitorship.update_attributes({:active => false})
    end
end
