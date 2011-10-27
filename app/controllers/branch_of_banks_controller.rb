# coding: utf-8
class BranchOfBanksController < ApplicationController
  def index
    @branches = BranchOfBank.find_by_sql("select p.id id, p.code code, p.name name, d.name parent from fin.division d 
      join FIN.division p on d.id = p.parent_id where p.code < '900' order by d.code, p.code")    
  end

end