#To restart delayed_job workers..
run "sudo monit -g dj_helpkit restart all"

puts "***** AFTER_RESTART is being called"
on_utilities("sphinx_sla") do
  puts "******* GOING to configure and index for thinking_sphinx"
  
  run "bundle exec rake thinking_sphinx:configure"
  run "bundle exec rake thinking_sphinx:index"
  execute "monit reload"
end
