class ContactMergeController < ApplicationController
  include ApplicationHelper

  before_filter :source_user
  before_filter :set_target_users, :check_limits, :only => [:confirm, :merge]

  def new
    @contact_search = Array.new
    render :partial => "new"
  end

  def search
    begin
      items = search_users.results.reject(&:parent_id?)
    rescue
      items = scoper.matching_users_from(params[:v]).without(@source_user).all(:conditions => { :string_uc04 => nil }, 
        :include => [:user_emails, :avatar, :company])
    end
    r = { :results => search_results(items) }
    render :json => r.to_json
  end
  
  def confirm
    render :partial => "confirm"
  end
  
  def merge
    if @error.blank?
      @target_users.each do |target|
        target.deleted = true
        target.user_emails.update_all({:user_id => @source_user.id, :primary_role => false, :verified => @source_user.active?})
        target.email = nil
        target.parent_id = @source_user.id
        target.save
      end
      @source_user.save
      
      # Resque.enqueue(Workers::MergeContacts, {:source => params[:parent_user], :targets => params[:target]})
      MergeContacts.perform_async({:parent => params[:parent_user], :children => params[:target]})
      flash[:notice] = t('merge_contacts.merge_progress')
    else
      flash[:error] = t('merge_contacts.validation')+@error
    end
    redirect_to contact_path(@source_user.id)
  end

  protected

    def scoper
      current_account.contacts
    end

  private

    def search_users
      options = { :load => { User => { :include => [{ :account => :features}, 
                                                    :user_emails, :company, :avatar] }}, :size => 100 }
      Search::EsIndexDefinition.es_cluster(current_account.id)
      items = Tire.search Search::EsIndexDefinition.searchable_aliases([User], current_account.id),options do |tire_search|
         tire_search.query do |q|
           q.filtered do |f|
             f.query { |q| q.match [ 'email', 'name', 'phone', 'user_emails.email' ], 
                          SearchUtil.es_filter_key(params[:v], false), 
                          :analyzer => "include_stop", :type => :phrase_prefix 
                      }
             f.filter :term, { :account_id => current_account.id }
             f.filter :term, { :deleted => false }
             f.filter :term, { :helpdesk_agent => false }
             f.filter :not,  { :filter => { :ids => {:values => [@source_user.id]} } }
           end
         end
         tire_search.sort { by :name, 'asc' }
      end
    end

    def search_results items
      items.map do |i| 
        {
          :id => i.id, 
          :name => i.name, 
          :email => i.email, 
          :title => i.job_title, 
          :company => i.company_name,
          :user_emails => i.emails.join(","),
          :twitter => i.twitter_id.present?,
          :facebook => i.fb_profile_id.present?,
          :phone => i.phone.present?, 
          :searchKey => i.emails.join(",")+i.name, 
          :avatar =>  i.avatar ? i.avatar.expiring_url("thumb",30.days.to_i) : is_user_social(i, "thumb")
        }
      end
    end

    def source_user
      @source_user = scoper.find_by_id(params[:parent_user])
      unprocessable_entity if @source_user.nil?
    end

    def set_target_users
      @target_users = scoper.without(@source_user).where({:id => params[:target]})
    end

    def check_limits
      @error=""
      User::MERGE_VALIDATIONS.each do |att|
        set_error(att[0], att[1]) if exceded_user_attribute(att[0], att[1])
      end
    end

    def exceded_user_attribute att, max
      [@source_user.send(att), @target_users.map{|x| x.send(att)}].flatten.compact.reject(&:empty?).length > max
    end

    def set_error att, max
      @error += "#{@error.blank? ? "" : ","} #{max} #{att}"
    end
end