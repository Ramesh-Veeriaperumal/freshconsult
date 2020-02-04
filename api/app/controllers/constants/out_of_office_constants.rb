module OutOfOfficeConstants
  REQUEST_PERMITTED_PARAMS = %i[start_time end_time].freeze

  OUT_OF_OFFICE_INDEX = 'api/v1/out-of-offices/'.freeze

  OUT_OF_OFFICE_SHOW = 'api/v1/out-of-offices/%{out_of_office_id}'.freeze
end
