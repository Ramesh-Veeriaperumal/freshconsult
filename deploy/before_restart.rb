#delayed_job monit has some problem with file permissions.
#refer http://community.engineyard.com/discussions/problems/1485-delayed_job-worker-not-starting-permission-denied
run "sudo chmod 755 #{release_path}/script/runner"
