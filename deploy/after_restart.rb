#To restart delayed_job workers..
run "sudo monit -g dj_helpkit restart all"

#Not a smart way...
on_utilities("sphinx_sla") do
  unless FileTest.exist?("#{release_path}/config/#{environment}.sphinx.conf")
    run "bundle exec rake thinking_sphinx:configure"
    run "bundle exec rake thinking_sphinx:index"
    run "bundle exec rake thinking_sphinx:start"
    #execute "monit reload"
  end
end
