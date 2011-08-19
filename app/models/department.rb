class Department < ActiveRecord::Base
  establish_connection :personnel
  self.abstract_class = true
#  set_inheritance_column 'parent_id'
end
