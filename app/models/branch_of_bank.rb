class BranchOfBank < Commerce
  has_many :performances
  set_table_name "FIN.DIVISION_PLAN"
  set_inheritance_column :ruby_type

 # getter for the "type" column
 def device_type
  self[:type]
 end

 # setter for the "type" column
 def device_type=(s)
  self[:type] = s
 end
end