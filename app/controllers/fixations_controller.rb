# coding: utf-8
class FixationsController < ApplicationController
  before_filter :find_master, :only => 'show_workers_by_master'
  def get_master
  end
  
  def show_workers_by_master
    slave_ids = []
    slave_ids = Fixation.select(:worker_id).where('master_id=?', params[:master][:master_id])
    if slave_ids.size > 0
      ids = slave_ids.join(',')
    else
      ids = '0'
    end
    
    @slaves = Worker.find_by_sql('select lastname from emp2doc where id_emp in ('+ids+')')
#    @slaves = Fixation.where('master_id=?', params[:master][:master_id]).workers
  end
  
  def new
    @fixation = Fixation.new
  end
  
  def create
    @fixation = Fixation.new params[:fixation]
    if not @fixation.save
      render :new
    else
      redirect_to :actions => 'show_workers_by_master'
    end
  end
  
  private
  
  def find_master
    @master = Worker.select('lastname').where('id_emp=?', params[:master][:master_id]).first
  end
end