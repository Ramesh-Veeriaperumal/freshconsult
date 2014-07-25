# considering the type of storage
# in development mode we can have only mysql set
# in staging and production mode the datastore is riak,mysql,s3

storage = YAML::load(ERB.new(File.read("#{Rails.root}/config/text_datastore.yml")).result)

storage = (storage[Rails.env] || storage).symbolize_keys

$primary_cluster = storage[:primary_storage]
$secondary_cluster = storage[:secondary_storage]
$backup_cluster = storage[:backup_storage]