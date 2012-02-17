# coding: utf-8
class Worker < Personnel
  self.table_name = "emp2doc"
  has_many :values, :class_name => 'Value'
#  has_many :fixations, :foreign_key => 'worker_id'
end