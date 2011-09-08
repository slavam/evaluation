class Department < ActiveRecord::Base
  establish_connection :personnel
  self.abstract_class = true
end
