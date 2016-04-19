# considering the type of storage
# in development mode we can have only mysql set
# in staging and production mode the datastore is riak,mysql,s3

archive_storage_yml = YAML::load(ERB.new(File.read("#{Rails.root}/config/archive_datastore.yml")).result)

archive_storage = (archive_storage_yml[Rails.env] || archive_storage_yml).symbolize_keys

$archive_store = archive_storage[:archive_primary_storage]
