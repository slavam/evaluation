# coding: utf-8
class Personnel < ActiveRecord::Base
  establish_connection :personnel
  self.abstract_class = true
end
