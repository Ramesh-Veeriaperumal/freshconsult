class Admin::Social::TwitterStreamsController < Admin::Social::StreamsController

  include Social::Twitter::Constants
  include Social::SmartFilter

  before_filter { access_denied unless current_account.basic_twitter_enabled? }
  before_filter :add_stream_allowed?, :only => [:new, :create]
  before_filter :load_item, :only => [:edit, :update, :destroy]
  before_filter :load_ticket_rules, :load_smart_filter_rule, :only => [:edit]
  before_filter :validate_params, :only => [:create, :update]
  

  def new
    @twitter_stream = scoper.new
    @twitter_stream.data = {
      :kind => TWITTER_STREAM_TYPE[:custom]
    }
    load_ticket_rules
  end

  def create
    twitter_stream_params = construct_stream_params 
    @twitter_stream       = scoper.new(twitter_stream_params)
    save_success          = @twitter_stream.save unless params[:twitter_stream][:includes].empty?

    if save_success
      ticket_rule_params = update_ticket_rules
      flash[:notice] = @ticket_error_flash.nil? ? I18n.t(:'flash.stream.created'): @ticket_error_flash
    else
      flash[:notice] = I18n.t(:'flash.stream.create_error')
    end
    redirect_to admin_social_streams_url
  end

  def preview
    unless params[:includes].blank?
      query_hash = {
        :q                => params[:includes],
        :exclude_keywords => params[:excludes],
        :exclude_handles  => params[:exclude_twitter_handles],
        :type             => Social::Constants::SEARCH_TYPE[:custom]
      }
      handle = current_account.random_twitter_handle
      fetch_options = {
        :sort_order => :desc,
        :count => LIVE_SEARCH_COUNT
      }
      @social_error_msg, query, feeds, next_results, refresh_url, next_fetch_id =
        Social::Twitter::Feed.fetch_tweets(handle, query_hash, nil, nil, fetch_options)
      @feeds = feeds.first(10) unless @social_error_msg
    end
    
    respond_to do |format|
      format.json { render :json => @feeds }
    end
  end

  def update
    update_twitter_handle if params[:social_twitter_handle]
    update_twitter_stream if params[:twitter_stream] and @ticket_error_flash.nil?
    update_dm_rule(@twitter_handle) if params[:dm_rule] and @ticket_error_flash.nil?
    update_ticket_rules if params[:social_ticket_rule] and @ticket_error_flash.nil?    
    update_smart_filter_rule if params[:smart_filter_rule] and @ticket_error_flash.nil? #check if smart filter is enables

    unless @ticket_error_flash.nil?
      flash[:notice] = @ticket_error_flash
      redirect_to :action => 'edit'
    else
      flash[:notice] = t('admin.social.flash.stream_updated', :stream_name => @twitter_stream.name)
      redirect_to admin_social_streams_url
    end
  end

  def smart_filter_feature_enabled?
    Account.current.twitter_smart_filter_enabled?
  end
 
  def destroy
    unless @twitter_stream.data[:kind] == TWITTER_STREAM_TYPE[:default]
      flash[:notice] = t('admin.social.flash.stream_deleted', :stream_name => @twitter_stream.name)
      @twitter_stream.destroy
      redirect_to admin_social_streams_url
    end
  end

  private
  
  def update_twitter_handle
    twitter_handle_params = construct_handle_params
    if @twitter_handle.update_attributes(twitter_handle_params)
       @twitter_stream.update_attributes({:accessible_attributes => stream_accessible_params(@twitter_stream)})
    else
      @ticket_error_flash = t('admin.social.flash.stream_save_error')
     end
  end
  
  def update_twitter_stream
    twitter_stream_params = construct_stream_params 
    twitter_data   = @twitter_stream.data
    twitter_handle = @twitter_stream.twitter_handle
    default_search = twitter_handle.formatted_handle unless twitter_handle.nil?
    if(twitter_data[:kind] == TWITTER_STREAM_TYPE[:default] && !twitter_stream_params[:includes].include?(default_search))
      twitter_stream_params[:includes] << default_search
    end

    #check for default handle assoc
    twitter_stream_params.merge!({:social_id => twitter_handle.id}) if twitter_data[:kind] == TWITTER_STREAM_TYPE[:default]
    
    unless twitter_stream_params[:includes].empty?
      unless @twitter_stream.update_attributes(twitter_stream_params)
        @ticket_error_flash = t('admin.social.flash.stream_save_error')
      end
    end
  end
  
  def mention_group_id
     group_id = params[:mention][:group_assigned].to_i if params[:mention]
  end
  
  def construct_stream_params
    twitter_stream = {
      :name     => params[:twitter_stream][:name],
      :includes => params[:twitter_stream][:includes].split(',').flatten,
      :excludes => params[:twitter_stream][:excludes].split(',').flatten
    }
    twitter_stream.merge!(construct_filter_data)
    twitter_stream.merge!(gnip_data) if @twitter_stream.nil?
    twitter_stream.merge!({:social_id => params[:twitter_stream][:social_id]}) unless params[:twitter_stream][:social_id].nil?
    twitter_stream.merge!({:accessible_attributes => stream_accessible_params(@twitter_stream)})
    twitter_stream
  end
  
  def construct_handle_params
    social_twitter_handle = {
      :product_id           => params[:social_twitter_handle][:product_id],
      :dm_thread_time       => params[:social_twitter_handle][:dm_thread_time]
    }
    if smart_filter_feature_enabled? && update_smart_filter_setting? 
      Social::SmartFilterInitWorker.perform_async({:smart_filter_init_params => smart_filter_init_params, :account_id => Account.current.id}) if @twitter_handle.smart_filter_enabled.nil?
      social_twitter_handle.merge!({:smart_filter_enabled => params[:smart_filter_enabled]})
    end
    social_twitter_handle
  end

  def update_ticket_rules
    deleted_rules = Array.new
    params[:social_ticket_rule].each do |rule|
      group_id = rule[:group_id].to_i unless (rule[:group_id].to_i == 0)
      product_id = rule_product_id
      if rule[:includes].blank? and rule[:ticket_rule_id].blank?
        @ticket_error_flash = t('admin.social.flash.ticket_rule_error') if (group_id)
        next 
      end
      if (rule[:includes].blank? or rule[:deleted] == "true")
        deleted_rules << rule[:ticket_rule_id]  unless rule[:ticket_rule_id].blank?
        next
      end
      rule_params = {
        :filter_data => {
          :includes => rule[:includes].split(',').flatten
        },
        :action_data => {
          :product_id => product_id,
          :group_id   => group_id
        }
      }
      if rule[:ticket_rule_id].empty?
        ticket_rule = @twitter_stream.ticket_rules.new(rule_params)
        ticket_rule.save
      else
        @twitter_stream.ticket_rules.find_by_id(rule[:ticket_rule_id]).update_attributes(rule_params)
      end
    end
    delete_rules(deleted_rules.compact) 
  end

  def update_smart_filter_rule
    rule = params[:smart_filter_rule]
    if params[:smart_filter_enabled] == SMART_FILTER_ON
      smart_rule_params = @twitter_stream.build_smart_rule(rule)
      if rule[:ticket_rule_id].empty?
        ticket_rule = @twitter_stream.ticket_rules.new(smart_rule_params)
        ticket_rule.save
      else
        @twitter_stream.ticket_rules.find_by_id(rule[:ticket_rule_id]).update_attributes(smart_rule_params)
      end  
    else
      delete_rules(rule[:ticket_rule_id])
      #delete if rule exist
    end    
  end

  
  def delete_rules(deleted_rules)
    Social::TicketRule.delete_all ["id IN (?) AND account_id = ? AND stream_id =?", deleted_rules, current_account.id, @twitter_stream.id] unless deleted_rules.empty?
  end


  def gnip_data
   {
      :data => {
        :kind => TWITTER_STREAM_TYPE[:custom]
      }
    }
  end

  def validate_params
    if params[:twitter_stream]
      params[:twitter_stream][:includes] = [] if params[:twitter_stream][:includes].blank?
      params[:twitter_stream][:excludes] = [] if params[:twitter_stream][:excludes].blank?
    end
  end

  def scoper
    current_account.twitter_streams
  end

  def load_item
    @twitter_stream = current_account.twitter_streams.find_by_id(params[:id])
    @twitter_handle = @twitter_stream.try(:twitter_handle)
    redirect_to admin_social_streams_url unless @twitter_stream
  end

  def load_ticket_rules
    @ticket_rules = @twitter_stream.ticket_rules
  end

  def load_smart_filter_rule
    @smart_filter_rule = @twitter_stream.smart_filter_rule
  end

  def construct_filter_data
    excluded_handles = {:exclude_twitter_handles => []}
    params[:twitter_stream][:filter].split(',').map{|f| excluded_handles[:exclude_twitter_handles] << f.gsub(/^@/,'')}
    {:filter => excluded_handles}
  end
  
  
  private

  def add_stream_allowed?
    redirect_to admin_social_streams_url unless current_account.add_custom_twitter_stream?
  end
  
  def rule_product_id
    if @twitter_stream.custom_stream? 
      product_id = params[:social_twitter_stream][:product_id] unless params[:social_twitter_stream].blank? 
    else
      product_id = params[:social_twitter_handle][:product_id] unless params[:social_twitter_handle].blank? 
    end
    product_id = product_id.blank? ? nil : product_id.to_i 
  end

  def update_smart_filter_setting?
    return false if @twitter_handle.smart_filter_enabled.nil? && 
                    params[:smart_filter_enabled] != SMART_FILTER_ON 
    true        
  end

   def smart_filter_init_params 
    {
      "account_id" => @twitter_handle.twitter_user_id
    }.to_json
  end
end