def all_instances_of(engine)
  utility_instances = []
  config.node['utility_instances'].each do |utility|
    if utility['name'].include?(engine)
      utility_instances << utility['name']
    end
  end
  utility_instances << 'freshdesk_utility' if utility_instances
  utility_instances
end

#To restart delayed_job workers..
on_utilities(all_instances_of("freshdesk_utility")) do
  run "sudo monit -g dj_helpkit restart all"
end

# utility_name = "freshdesk_sphinx_delayed_jobs"

# freshdesk_utility = node['utility_instances'].find { |instance| instance['name'] == utility_name }
# utility_name = freshdesk_utility ? utility_name : "freshdesk_utility" 

# on_utilities(utility_name) do
#   #1. Need to revisit this again. 2. blank? doesn't work in deploy hooks.
#   sphinx_environment = node[:environment][:framework_env]
#   #sphinx_environment = "slave" if !node['db_slaves'].nil? and !node['db_slaves'].empty?
#   run "RAILS_ENV=#{sphinx_environment} bundle exec rake thinking_sphinx:configure"
#   if `ps aux | grep search[d]` == ""
#     run "bundle exec RAILS_ENV=#{sphinx_environment} rake thinking_sphinx:index"
#     run "RAILS_ENV=#{sphinx_environment} bundle exec rake thinking_sphinx:start"
#     #execute "monit reload"
#   end
# end


on_utilities(all_instances_of('resque')) do
	run "sudo monit restart all -g helpkit_resque" 
end
