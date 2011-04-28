#To restart delayed_job workers..
run "sudo monit -g dj_helpkit restart all"
run "chown -R deploy ./tmp"