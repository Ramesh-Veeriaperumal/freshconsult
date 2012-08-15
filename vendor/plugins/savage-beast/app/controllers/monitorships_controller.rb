class MonitorshipsController < ApplicationController
  before_filter :login_required #To do Shan

  cache_sweeper :monitorships_sweeper, :only => [:create, :destroy]

  def create
    @monitorship = Monitorship.find_or_initialize_by_user_id_and_topic_id(current_user.id, params[:topic_id])
    @monitorship.update_attributes({:active => true})
    respond_to do |format| 
      format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
      format.js
    end
  end
  
  def destroy
    Monitorship.update_all ['active = ?', false], ['user_id = ? and topic_id = ?', current_user.id, params[:topic_id]]
    respond_to do |format| 
      format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
      format.js
    end
  end
end
