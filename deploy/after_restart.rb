#To restart delayed_job workers..
run "sudo monit -g dj_helpkit restart all"

#To give the permissions for omniauth to create temp file
run "mkdir ./tmp/temp"
run "chown -R deploy ./tmp/temp"