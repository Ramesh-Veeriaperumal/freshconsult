class AddBigIntForAccountId < ActiveRecord::Migration
  shard :none
  def self.up
  	#execute("alter table admin_user_accesses MODIFY accessible_id bigint(20) unsigned")
	execute("alter table authorizations MODIFY user_id bigint(20) unsigned, MODIFY account_id bigint(20) unsigned")
	execute("alter table data_exports MODIFY account_id bigint(20) unsigned")
	execute("alter table deleted_customers MODIFY account_id bigint(20) unsigned")
	execute("alter table groups MODIFY business_calendar_id bigint(20) unsigned")
	execute("alter table helpdesk_dropboxes MODIFY droppable_id bigint(20) unsigned")
	execute("alter table installed_applications MODIFY application_id bigint(20) unsigned")
	execute("alter table social_tweets MODIFY account_id bigint(20) unsigned")
	execute("alter table social_twitter_handles MODIFY account_id bigint(20) unsigned")
	execute("alter table subscription_events MODIFY subscription_plan_id bigint(20) unsigned, MODIFY subscription_affiliate_id bigint(20) unsigned")
	execute("alter table wf_filters MODIFY user_id bigint(20) unsigned, MODIFY account_id bigint(20) unsigned")
	execute("alter table widgets MODIFY application_id bigint(20) unsigned")
	execute("alter table applications MODIFY account_id bigint(20) unsigned")
  end

  def self.down
  end
end
