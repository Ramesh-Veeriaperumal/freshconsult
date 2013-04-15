run "ln -nfs #{shared_path}/config/sphinx #{release_path}/config/sphinx"
run "ln -nfs #{shared_path}/config/sphinx.yml #{release_path}/config/sphinx.yml"
run "ln -nfs #{shared_path}/config/memcached.yml #{release_path}/config/memcached.yml"
run "ln -nfs #{shared_path}/config/database_cluster.yml  #{release_path}/config/database.yml"
run "ln -nfs #{shared_path}/config/elasticsearch.yml  #{release_path}/config/elasticsearch.yml"

# Added a compilation of core css files used under public/src/app
# All files in public/stylesheets/app will be ignored and cannot be checked in
run "bundle exec compass compile -e production"
run "bundle exec jammit"
