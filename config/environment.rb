# Load the rails application
require File.expand_path('../application', __FILE__)
require 'odbc_utf8'
require 'authlogic'

# Initialize the rails application
Evaluation::Application.initialize!

Encoding.default_internal = 'UTF-8'