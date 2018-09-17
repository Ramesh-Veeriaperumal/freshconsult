#Discard changes to these files
fileList=( "config/database.yml" "lib/helpdesk/initializers/memcached.rb" "lib/helpdesk/initializers/redis.rb" )
for file in "${fileList[@]}"
do
  git checkout -- $file
done

# Delete these files
toRemove=( "config/database.yml-e" "test/*.log" "test/api/suites/tempp*.rb" )
for file in "${toRemove[@]}"
do
  rm $file
done
