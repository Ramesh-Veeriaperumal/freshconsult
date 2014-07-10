class MobihelpController < ApplicationController
  skip_before_filter :require_user
  skip_before_filter :check_privilege
  before_filter :validate_credentials

  include Mobihelp::MobihelpHelperMethods

end
