class DefaultValidatorNotImplementedError < StandardError
 # API Validators are developed to provide enhanced error messages and
 # custom_codes to the users for clear understanding. Validations that are
 # possible in default validators can be achieved using the API Validators,
 # as a result API Validators wont support the default ones.
 # Please extend if you have such requirement.
end
