class MonitorshipsController < ApplicationController
  
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :require_user #To do Shan

  def create
    @monitorship = Monitorship.where(user_id: current_user.id, topic_id: params[:topic_id]).first_or_initialize
    @monitorship.update_attributes({:active => true})
    respond_to do |format| 
      format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
      format.js
    end
  end
  
  def destroy
    Monitorship.where(['user_id = ? and topic_id = ?', current_user.id, params[:topic_id]]).update_all(['active = ?', false])
    respond_to do |format| 
      format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
      format.js
    end
  end
end
