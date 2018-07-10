#
# TODO:
# Bugs::
# * Custom field compatibility - field_<account_id> is not valid anymore
# * Attachments in canned responses and templates
# * we need to move launch party features also
# * Verification Script to compare
#   * counts + associations
#   * data itself - not sure this is needed ??
# * Moving git keys to recipes
#
#
# * Two accounts in the same shard -> go to same sandbox db. An Id of account A in prod DB might clash with ID of account B in sandbox
# * how do we prune for records with no id column ?? --> maintain a seperate list and prune them seperately ??
#
#
# ------------------------------------------------------------
#
# reload!
# Account.first.make_current
# Agent.first.user.make_current
# Account.current.creat_sandbox_account
# Admin::CreateSandboxAccount.new.perform({:account_id => Account.current.id, :user_id => User.current.id})
# job = Account.current.sandbox_jobs.create(:sandbox_account_id => Account.current.sandbox_account.sandbox_account_id)
# Admin::ProvisionSandbox.new.perform({:job_id => job.id})
#
# ------------------------------------------------------------
# Sync::Workflow.new(6).provision_staging_instance
# ------------------------------------------------------------
#
#
# merge_sandbox = Sync::Workflow.new(6, 1)
# success, conflicts = merge_sandbox.move_staging_config_to_prod({:name => "Arvind R", :email => "arvind@freshdesk.com"}, "Merging staging to prod #{Time.now.strftime("%H:%M:%S")}")
#
# merge_sandbox.update_prod_config  ## Relations
#
# sa.agents_config = true
# sa.groups_config = true
# sa.ticket_fields_config = true
# sa.ticket_field_def_config = true
#
# sa.in_config
#
# -------------------------------
#
# CONFIGS  = ["observer_rules", "ticket_field_def"]
# Account.first.make_current
# Account.current.sandbox_account
# Account.current.sandbox_jobs
#
# Account.current.creat_sandbox_account
# Admin::CreateSandboxAccount.new.perform({:account_id => Account.current.id, :user_id => User.current.id})
# Admin::ProvisionSandbox.new.perform_async({:sandbox_account_id => Account.current.sandbox_account.id})
#

# Model Insert Order Logic

# @model_dependencies.keys.each do |model|
#   @sorter.add(model, @model_dependencies[model].map{|m| m[:classes]}.flatten)
#   #Automated Rule's serialized columns refer flexifields, ticket fields and nested fields
#   if ["VaRule", "Helpdesk::TicketTemplate", "SlaPolicy"].include?(model)
#     @sorter.add(model, ["FlexifieldDefEntry", "Helpdesk::TicketField", "Helpdesk::NestedTicketField", "User", "Group", "Helpdesk::Tag", "BusinessCalendar", "Product"])
#   end
# end
# @model_insert_order = @sorter.sort
# #removing Account from models to be migrated. It will always be the first model
# #as all the tables migrated depends on it!
# @model_insert_order.delete("Account")

# Build depency list

# @model_dependencies = {}
# accepted_models = [@model_directories.keys, "Account"].flatten
# @model_directories.keys.each do |model|
#   @model_dependencies[model] = Sync::DependencyList.new(model,accepted_models).construct_dependencies
# end

# table_directory_hash

# def table_directory_hash(account_id, repo_path)
#   tables = {}
#   tdir = {}
#     account = Account.find(account_id).make_current
#     RELATIONS.each do |relation|
#       ftoc = Sync::FileToConfig.new("teting", relation[0], account)
#       tdir[relations[0]]  = ftoc.table_directories
#     end
#     p "#{tdir.inspect}"
# end
