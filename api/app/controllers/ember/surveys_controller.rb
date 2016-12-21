module Ember
  class SurveysController < ::SurveysController
    def decorator_options
      super(version: 'private')
    end
  end
end