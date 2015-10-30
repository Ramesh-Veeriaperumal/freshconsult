class PlanChangeWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :plan_change, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(drop_features)
    account = Account.current
    drop_features.each do |drop_feature|
      drop_method = "drop_#{drop_feature}_data"
      # Adding this block due to dynamic sections bug
      # Ref: https://github.com/freshdesk/helpkit/commit/7da2749537bfac540bbf8495d144e8a68c9c9e0d
      #
      begin
        send(drop_method, account) if respond_to?(drop_method)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def drop_customer_slas_data(account)
    #account.sla_policies.destroy_all(:is_default => false) #wasn't working..
    Helpdesk::SlaPolicy.destroy_all(:account_id => account.id, :is_default => false)
    update_all_in_batches({ :sla_policy_id => account.sla_policies.default.first.id }) { |cond|
      account.companies.where(@conditions).limit(@batch_size).update_all(cond)
    }
    #account.sla_details.update_all(:override_bhrs => true) #this too didn't work.
    update_all_in_batches({ :override_bhrs => true }){ |cond| 
      account.sla_policies.default.first.sla_details.where(@conditions).limit(@batch_size).update_all(cond)
    }
  end

  def drop_multiple_business_hours_data(account)
    update_all_in_batches({ :time_zone => account.time_zone }){ |cond| 
      account.all_users.where(@conditions).limit(@batch_size).update_all(cond)
    }
  end

  def drop_multi_product_data(account)
    account.products.destroy_all

    #We are not updating the email_config_id or product_id in Tickets model knowingly.
    #Tested, haven't faced any problem with stale email config ids or product ids.
  end

  def drop_facebook_data(account)
    account.facebook_pages.destroy_all
  end

  def drop_twitter_data(account)
    account.twitter_handles.destroy_all
  end

  def drop_custom_domain_data(account)
    account.main_portal.portal_url = nil
    account.save!
  end

  def drop_multiple_emails_data(account)
    account.global_email_configs.find(:all, :conditions => {:primary_role => false}).each{|gec| gec.destroy}
  end

  def drop_layout_customization_data(account)
    account.portal_pages.destroy_all
    account.portal_templates.each do |template|
      template.update_attributes( :header => nil, :footer => nil, :layout => nil, :head => nil)
    end
  end

  def drop_css_customization_data(account)
    update_all_in_batches({ :custom_css => nil, :updated_at => Time.now }){ |cond| 
      account.portal_templates.where(@conditions).limit(@batch_size).update_all(cond)
    }
    drop_layout_customization_data(account)
  end

  def drop_custom_roles_data(account)
    account.technicians.each do |agent|
      if agent.privilege?(:manage_account)
        #Array is returned. So removing the []
        new_roles = account.roles.account_admin
      elsif agent.roles.exists?(:default_role => true)
        new_roles = agent.roles.default_roles
      else
        #Array is returned. So removing the []
        new_roles = account.roles.agent
      end
      agent.roles = new_roles
      agent.save
    end

    Role.destroy_all(:account_id => account.id, :default_role => false )
  end

  def drop_dynamic_content_data(account)
    update_all_in_batches({ :language => account.language }){ |cond| 
      account.all_users.where(@conditions).limit(@batch_size).update_all(cond) 
    }
    account.account_additional_settings.update_attributes(:supported_languages => [])
  end

  def drop_mailbox_data(account)      
    account.imap_mailboxes.destroy_all
    account.smtp_mailboxes.destroy_all
  end

=begin
  @conditions, @batch size are created using VALUES hash that is passed
  If need to check additional conditions, pass in a where that is prepended before the where using @conditions

  Invocation:
  update_all_in_batches(VALUES) { |c| account.users.where(@conditions).limit(@batch_size).update_all(c) }
=end

  def update_all_in_batches(change_hash)
    change_hash.symbolize_keys!
    frame_conditions(change_hash)
    begin
      updated_count = yield(change_hash)
    end while updated_count == @batch_size
    nil
  end

  def frame_conditions(change_hash)
    # Excluding created_at, updated_at as != is bad check
    @conditions = [[]]
    @batch_size = change_hash.delete(:batch_size) || 500
    change_hash.except(:created_at, :updated_at).each do |key ,value|
      if value.nil?
        @conditions[0] << "`#{key}` is not null"
      else
        @conditions[0] << "`#{key}` != ?"
        @conditions << value
      end
    end
    @conditions[0] = @conditions[0].join(" and ")
    nil
  end
end
