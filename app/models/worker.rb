class Worker < Personnel
  set_table_name "emp2doc"
  has_many :values, :class_name => 'Value'
end