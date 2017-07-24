class Admin::UserSkillsController < Admin::AdminController

  include Admin::UserSkillsHelper

  before_filter { |c| c.requires_this_feature :skill_based_round_robin }
  before_filter :skills_present?
  before_filter :set_user_role, :only => :index
  before_filter :load_user, :except => :index
  before_filter :set_filter_data, :check_skill_update_access, :only => [ :update ]
  
  def index
    load_groups_trimmed_version
    set_filtered_group
    load_users
    @skills = gon.allSkills = current_account.skills_trimmed_version_from_cache.map{|skill| {:skill_id=>skill.id, :name=>skill.name}}
    # using gon variable to pass rails-variables directly in js files
  end

  def show
    skill_details = @user.user_skills.preload(:skill).map do |user_skill|
      {:id => user_skill.id, :rank => user_skill.rank, :skill_id => user_skill.skill_id, 
        :name => user_skill.skill.name}
    end
    render :json => skill_details
  end

  def update
    render :json => { :success => @user.update_attributes(params.slice(:user_skills_attributes)) }
  end

  private

    def skills_present?
      if privilege?(:manage_skills)
        redirect_to(admin_skills_path) unless current_account.skills_trimmed_version_from_cache.present?
      end
    end

    def set_user_role
      @is_admin = gon.is_admin = privilege?(:manage_skills)
      # using gon variable to pass rails-variables directly in js files
    end

    def load_user
      if privilege?(:manage_skills) or current_user.has_edit_access?(params[:user_id])
        @user = current_account.technicians.find_by_id(params[:user_id])
      else
        render :json => { :success => 403 }
      end
    end

    def set_filter_data
      user_skills = params[:user_skills_attributes] || []
      params[:user_skills_attributes] = user_skills.is_a?(Array) ? user_skills : ActiveSupport::JSON.decode(params[:user_skills_attributes])
    end

    def group_scoper
      @is_admin ? current_account.groups : current_user.accessible_groups
    end

    def load_groups_trimmed_version
      @groups = group_scoper.trimmed
    end

    def set_filtered_group
      group_id = params[:group_id]
      group_id ||= @groups.present? && @groups.first.id if !@is_admin #if supervisor
      @filtered_group = group_id.present? && group_scoper.find_by_id(group_id)
    end

    def load_users
      @users = user_scoper.technicians.trimmed.preload(:skills) if @filtered_group.present? || @is_admin
    end

    def user_scoper
      @filtered_group.present? ? @filtered_group.agents : (current_account.users if @is_admin)
    end

    def check_skill_update_access
      return if privilege?(:manage_skills)
      new_skill_ids = params[:user_skills_attributes].map { |skill_set| skill_set[:skill_id] }
      unless new_skill_ids.uniq.sort == @user.skill_ids.uniq.sort
        render :json => { :success => 403 }
      end
    end
end
