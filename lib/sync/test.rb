=begin

TODO:
Bugs::
* Custom field compatibility - field_<account_id> is not valid anymore
* Attachments in canned responses and templates
* we need to move launch party features also
* Verification Script to compare
  * counts + associations
  * data itself - not sure this is needed ??
* Moving git keys to recipes


* Two accounts in the same shard -> go to same sandbox db. An Id of account A in prod DB might clash with ID of account B in sandbox
* how do we prune for records with no id column ?? --> maintain a seperate list and prune them seperately ??


------------------------------------------------------------

reload!
Account.first.make_current
Agent.first.user.make_current
job = Account.current.sandbox_jobs.create(:sandbox_account_id => Account.current.sandboxes.first.sandbox_account_id)
Admin::ProvisionSandbox.new.perform({:job_id => job.id})

------------------------------------------------------------
Sync::Workflow.new(6).provision_staging_instance
------------------------------------------------------------


merge_sandbox = Sync::Workflow.new(6, 1)
success, conflicts = merge_sandbox.move_staging_config_to_prod({:name => "Arvind R", :email => "arvind@freshdesk.com"}, "Merging staging to prod #{Time.now.strftime("%H:%M:%S")}")

merge_sandbox.update_prod_config  ## Relations

sa.agents_config = true
sa.groups_config = true
sa.ticket_fields_config = true
sa.ticket_field_def_config = true

sa.in_config

-------------------------------

CONFIGS  = ["observer_rules", "ticket_field_def"]
Account.first.make_current
Account.current.sandboxes
Account.current.sandbox_jobs

#Account.current.sandboxes.create(:staging_account_id => 3, :status => Admin::Sandbox::Account::STATUS_KEYS_BY_TOKEN[:stopped])
#Admin::ProvisionSandbox.new.perform_async({:sandbox_account_id => Account.current.sandboxes.first.id})

=end
