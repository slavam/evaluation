class Subdivision < Department
#  belongs_to :maindivision, :class_name => 'Maindivision', :foreign_key => 'parent_id'
  set_table_name "div2doc"
end