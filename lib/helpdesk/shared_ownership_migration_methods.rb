module Helpdesk::SharedOwnershipMigrationMethods

  include Cache::FragmentCache::Base
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::OthersRedis

  def remove_launch_party_feature(account = Account.current)
    account.rollback(:shared_ownership) if account.launched?(:shared_ownership)
  end

  def add_launch_party_feature(account = Account.current)
    account.launch(:shared_ownership)
  end

  def remove_feature(account = Account.current)
    account.features.shared_ownership.destroy
  end

  def add_feature(account = Account.current)
    account.features.shared_ownership.create
  end

  def delete_internal_fields(account = Account.current)
    account.ticket_fields.where(:field_type => [:default_internal_group, :default_internal_agent]).destroy_all
  end

  def add_internal_fields(account = Account.current)
    ticket_fields = account.ticket_fields
    agent_position = ticket_fields.select{|tf| tf.field_type == "default_agent"}.first.position
    ticket_fields.create!([
      {
        :name => "internal_group",
        :label => "Internal Group",
        :description => "Select the Internal group",
        :active => true,
        :field_type => "default_internal_group",
        :required => false,
        :visible_in_portal => false,
        :editable_in_portal => false,
        :required_in_portal => false,
        :required_for_closure => false,
        :default => true,
        :position => agent_position+1,
        :field_options => {}
      },
      {
        :name => "internal_agent",
        :label => "Internal Agent",
        :description => "Select the Internal agent",
        :active => true,
        :field_type => "default_internal_agent",
        :required => false,
        :visible_in_portal => false,
        :editable_in_portal => false,
        :required_in_portal => false,
        :required_for_closure => false,
        :default => true,
        :position => agent_position+2,
        :field_options => {}
      }
      ])
  end

  def delete_status_groups(account = Account.current)
    account.status_groups.destroy_all
  end

  def clear_new_page_cache
    clear_fragment_caches
  end

end