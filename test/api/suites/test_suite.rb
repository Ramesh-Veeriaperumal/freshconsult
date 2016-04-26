tests_to_be_run = Dir.glob('test/api/**/*_test.rb')
first_argument  = []
second_argument = []
modules = ""
if ARGV.length > 2
  raise ArgumentError.new("Accepts only maximum of two arguments namely MODULES and INCLUDE_QUERY_TEST")
end
if !ARGV[0].nil?
	first_argument = ARGV[0].split("=")
	raise ArgumentError.new("First Argument should starts with INCLUDE_QUERY_TEST=") unless first_argument.first == "INCLUDE_QUERY_TEST"
end
if !ARGV[1].nil?
	second_argument = ARGV[1].split("=")
	raise ArgumentError.new("Second Argument should starts with MODULES=") unless second_argument.first == "MODULES"
end
if second_argument.length == 2
  modules = second_argument.last
	module_tests = Dir.glob("test/api/**/*{#{modules}}*_test.rb")
	tests_to_be_run = module_tests
end
if first_argument.length == 2
  include_query_test = first_argument.last
  unless include_query_test == 'true'
  	query_tests = "test/api/integration/queries/*{#{modules}}*_test.rb"
  	tests_to_be_run -= Dir.glob(query_tests)
  end
end
p "List of test files to be run: #{tests_to_be_run}"
tests_to_be_run.each { |file| require "./#{file}" }