#To restart delayed_job workers..
run "sudo monit -g dj_helpkit restart all"

on_utilities("sphinx_sla") do
  if `ps aux | grep search[d]`.blank? #Need to revisit this again..
    run "bundle exec rake thinking_sphinx:configure"
    run "bundle exec rake thinking_sphinx:index"
    run "bundle exec rake thinking_sphinx:start"
    #execute "monit reload"
  end
end
