require 'custom_fields/migrations/custom_field_data'
require 'custom_fields/view/dom_element'
require 'custom_fields/workers/nullify_deleted_custom_field_data'
require 'custom_fields/constants'

require 'has/custom_field'
require 'has/custom_field/callback_methods'
require 'has/custom_field/instance_methods'
require 'has/custom_field/meta_methods'
require 'has/custom_field/validation_methods'

require 'acts_as/custom_form'
require 'acts_as/custom_form/methods'

require 'inherits/custom_field'
require 'inherits/custom_field/methods'
require 'inherits/custom_field/api_methods'
require 'inherits/custom_field/constants'
require 'inherits/custom_field/CRUD_methods'
require 'inherits/custom_field/instance_methods'

require 'stores/custom_field_data'
require 'stores/custom_field_data/methods'

require 'stores/custom_field_choice'

require 'inherits/custom_fields_controller'
require 'inherits/custom_fields_controller/REST_methods'



ActiveRecord::Base.extend Has::CustomField::ActiveRecordMethods
ActiveRecord::Base.extend Inherits::CustomField::ActiveRecordMethods
ActiveRecord::Base.extend ActAs::CustomForm::ActiveRecordMethods
ActiveRecord::Base.extend Stores::CustomFieldData::ActiveRecordMethods
ActiveRecord::Base.extend Stores::CustomFieldChoice::ActiveRecordMethods

ActionController::Base.extend  Inherits::CustomFieldsController::ActionControllerMethods
