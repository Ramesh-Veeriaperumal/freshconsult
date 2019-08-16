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
    check_rules if @twitter_stream.default_stream? && !dont_convert_tweets_to_ticket?
    update_twitter_handle if params[:social_twitter_handle] and @ticket_error_flash.nil?
    update_twitter_stream if params[:twitter_stream] and @ticket_error_flash.nil?
    update_dm_rule(@twitter_handle) if params[:dm_rule] and @ticket_error_flash.nil?
    update_rules if params[:social_ticket_rule] and @ticket_error_flash.nil?
    
    unless @ticket_error_flash.nil?
     show_error
     return
    else
      flash[:notice] = t('admin.social.flash.stream_updated', :stream_name => @twitter_stream.name)
      redirect_to admin_social_streams_url
    end
  end

  def update_rules
    if @twitter_stream.custom_stream?
      update_ticket_rules
      return 
    end
    return construct_rule_params if Account.current.mentions_to_tms_enabled?

    if dont_convert_tweets_to_ticket?
      @twitter_stream.ticket_rules.delete_all
    elsif rules_without_keywords?
      smart_filter_feature_enabled? ? update_smart_filter_rule_without_keywords : update_ticket_rules      
    else
      update_ticket_rules   
      update_smart_filter_rule_with_keywords if smart_filter_feature_enabled?
    end
  end

  def construct_rule_params
    if dont_convert_tweets_to_ticket?
      delete_all_rules = true
    elsif rules_without_keywords?
      if smart_filter_feature_enabled?
        smart_rules, deleted_rules = update_smart_filter_rule_without_keywords
      else
        rules, deleted_rules = update_ticket_rules
      end
    else
      rules, deleted_rules = update_ticket_rules
      smart_rules, deleted_rules_smart_filter = update_smart_filter_rule_with_keywords if smart_filter_feature_enabled?
    end
    stream_update_params = { accessible_attributes: stream_accessible_params(@twitter_stream) }
    params = {
      rules: rules,
      smart_rules: smart_rules,
      stream_update_params: stream_update_params,
      delete_all_rules: delete_all_rules,
      deleted_rules: deleted_rules,
      deleted_rules_smart_filter: deleted_rules_smart_filter
    }
    @twitter_stream.update_all_rules(params)
  end

  def show_error
    flash[:notice] = @ticket_error_flash
    redirect_to :action => 'edit'
  end

  def dont_convert_tweets_to_ticket?
    params.has_key?(:capture_tweet_as_ticket) && params[:capture_tweet_as_ticket].to_i.zero?
  end

  def rules_without_keywords?
    params[:keyword_rules].to_i.zero?
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
      @twitter_stream.update_attributes(accessible_attributes: stream_accessible_params(@twitter_stream)) unless Account.current.mentions_to_tms_enabled?
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
      :dm_thread_time       => params[:social_twitter_handle][:dm_thread_time],
      :capture_dm_as_ticket => params[:capture_dm_as_ticket].to_i
    }
    if smart_filter_feature_enabled? && update_smart_filter_setting? 
      social_twitter_handle.merge!({:smart_filter_enabled => smart_filter_enabled?})
    end
    social_twitter_handle
  end

  def check_rules
    unless rules_without_keywords?
      if (params[:social_ticket_rule].detect { |rule| rule[:includes].present? && !rule[:convert_all]}).nil? 
         @ticket_error_flash = t('admin.social.flash.empty_rule_error')
      end
    end
  end

  def update_ticket_rules
    keyword_filter_rules = []
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
      rule_params[:action_data].merge!({:convert_all => true}) if rule[:convert_all]
      if rule[:ticket_rule_id].empty?
        if publish_mention_rules?
          keyword_filter_rules << construct_mention_rules(rule_params, rule, 'create')
          next
        end
        ticket_rule = @twitter_stream.ticket_rules.new(rule_params)
        ticket_rule.save
      else
        if publish_mention_rules?
          keyword_filter_rules << construct_mention_rules(rule_params, rule, 'update')
          next
        end
        @twitter_stream.ticket_rules.find_by_id(rule[:ticket_rule_id]).update_attributes(rule_params)
      end
    end
    return keyword_filter_rules, deleted_rules if publish_mention_rules?

    delete_rules(deleted_rules.compact)
  end

  def publish_mention_rules?
    Account.current.mentions_to_tms_enabled? && !@twitter_stream.custom_stream?
  end


  def update_smart_filter_rule_with_keywords
    if params[:smart_filter_enabled] == SMART_FILTER_ON
      smart_rule = params[:smart_filter_rule_with_keywords]
      smart_rule.merge!(:with_keywords => 1)
      update_smart_filter_rule(smart_rule) 
    else
      sf_rule = @twitter_stream.smart_filter_rule
      return nil, sf_rule if Account.current.mentions_to_tms_enabled?
      
      delete_rules([sf_rule])
    end    
  end

  def update_smart_filter_rule_without_keywords
    if Account.current.mentions_to_tms_enabled?
      @deleted_rules = @twitter_stream.keyword_rules.map(&:id)
    else
      @twitter_stream.delete_keyword_rules
    end
    smart_rule = params[:smart_filter_rule_without_keywords]
    smart_rule.merge!(:with_keywords => 0)
    update_smart_filter_rule(smart_rule)
  end

  def update_smart_filter_rule(rule)
    smart_rule_params = @twitter_stream.build_smart_rule(rule)
    if rule[:ticket_rule_id].blank?
      return construct_mention_rules(smart_rule_params, rule, 'create') if Account.current.mentions_to_tms_enabled?

      ticket_rule = @twitter_stream.ticket_rules.new(smart_rule_params)
      ticket_rule.save
    else
      return construct_mention_rules(smart_rule_params, rule, 'update'), @deleted_rules if Account.current.mentions_to_tms_enabled?

      @twitter_stream.smart_filter_rule.update_attributes(smart_rule_params)
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
    return false if @twitter_handle.smart_filter_enabled.nil? && !smart_filter_enabled?
    true        
  end

  def smart_filter_enabled?
    unless dont_convert_tweets_to_ticket?
      rules_without_keywords? ? true : (params[:smart_filter_enabled] == SMART_FILTER_ON)
    else 
      false unless @twitter_handle.smart_filter_enabled.nil?
    end 
  end

  def construct_mention_rules(rule_params, rule, action)
    {
      rule_params: rule_params,
      rule: rule,
      action: action
    }
  end
end
