## Rubocop Custom errors
 We have introduced custom rubocop rules to catch rails(3.2)/gems deprecated methods. To differentiate errors from normal “pronto/rubocop”. we have added “rubocop_rails” in pronto message.

### Rails/QueryArgs
  Use `lambda`/`proc` with method chaining instead of a plain method call with key-value for conditions, orders, join, select and include.

Examples:
```rb
# bad
scope :something, where(something: true)
# good
scope :something, -> { where(something: true) }

# bad
scope :something, :conditions => { active: false }
# good
scope :something, -> { where(active: false) }

# bad
scope :something, :conditions => { active: false }, :order => ""something""
# good
scope :something, -> { where(active: true).order(something) 

# bad
scope :something, :include => { something: false }, :order => ""something""
# good
scope :something, -> { includes(something: true).order(something) }”

# bad
something.count(..., :conditions => <some_condition>)
# good
something.where(<some_condition>).count(...)

# bad
something.sum(..., :conditions => <some_condition>)
# good
something.where(<some_condition>).sum(...)

# bad
something.all(:conditions => <some_condition>, :order => 'some_order')
# good
something.where(<some_condition>).order('some_order').all

```

### Rails/FinderMethod
  This cop checks `find` methods. Finder methods which previously accepted "finder options" eg: find(:all), no longer do.
Also all dynamic methods except for find_by_... and find_by_...! are deprecated.

Examples:
```rb
# bad
User.find(:all, ...)
# good
User.where(...)

# bad
User.find_all_by_...(...)
# good
User.where(...)

# bad
User.find_last_by_...(...)
# good
User.where(...).last

# bad
User.scoped_by_...(...)
# good
User.where(...)

# bad
User.find_or_initialize_by_...(...)
# good
User.where(...).first_or_initialize

# bad
User.find_or_create_by_...(...)
# good
User.where(...).first_or_create

# bad
Topic.paginate_by_forum_id(id, order: 'something desc', page: page)
# good
Topic.where(forum_id: id).order('something desc').paginate(page: page)
```

### Rails/MatchRoute
  Routes using match must specify the request method.

Examples:
```rb
# bad
match '/' => 'root#index'
# good
match '/' => 'root#index', via: :get
get '/' => 'root#index’
```

### Rails/UpdateAllQuery
  This cop checks conditionally queries in update all

Examples:
```rb
# bad
User.update_all({name: 'test'},{name: 'test1'})
# good
User.where(name: 'test1').update_all(name: 'test')
```

### Rails/HasAndBelongsToMany(default rubocop)
  This cop checks has_and_belongs_to_many in associations.

Examples:
```rb
# bad
has_and_belongs_to_many :users, :join_table => "user_roles", :autosave => true
# good
has_many :user_roles, class_name: 'UserRole', autosave: true
has_many :users, through: :user_roles
```

### Rails/JsonGenerate
  This cop checks for JSON.Generate usage.

Examples:
```rb
# bad
JSON.generate(something)

# good
something.to_json
```

### Gem/WillPaginate
  This cop checks for paginate arguments as latest version restricted to accept only per_page, total_entries and page.

Examples:
```rb
# bad
something.paginate(:page => params[:page],:include => [:something],:per_page => 50)
# good
something.includes([:tag_uses]).paginate(:page => params[:page],:per_page => 50)

# bad
something.paginate(:page => params[:page],:order => "updated_at ASC",:per_page => 50)
# good
something.order("updated_at ASC").paginate(:page => params[:page],:per_page => 50)

```

### Gem/AwsS3
  This cop checks for S3 v1 usage.

Examples:
```rb
# bad
AwsWrapper::S3Object.store(file_path, file, bucket_name, server_side_encryption: :aes256, expires: 30.days)
# good
AwsWrapper::S3.put(bucket_name, file_path, file, server_side_encryption: 'AES256', expires: (Time.now + 30.days))

# bad
AwsWrapper::S3Object.url_for(path, bucket_name, options)
# good
AwsWrapper::S3.presigned_url(bucket_name, path, options)

# bad
AwsWrapper::S3Object.read(path, bucket_name)
# good
AwsWrapper::S3.read(bucket_name, path)
```

### Gem/AwsV1
  This cop checks for existing v1 client usage.

Examples:
```rb
# bad
AWS::SNS.new.client(...)
# good
Aws::SNS::Client.new(...)
```

### Gem/AwsGlobalVar
  This cop checks for existing v1 global variable usage.

Examples:
```rb
# bad
$sns_client = AWS::SNS.new.client(...)
# good
$sns_client = Aws::SNS::Client.new(...)
```
