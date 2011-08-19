# coding: utf-8
class SubdivisionsController < ApplicationController
  before_filter :find_department, :only => [:my_show, :edit, :update, :destroy]
  def index
    @subdivisions = Subdivision.select([:id_division, :parent_id, :division, :code_division]).order(:id_division).paginate :page => params[:page], :per_page => 20
  end
  
  def my_show
  end

  private
  def find_department
    @subdivisions = Subdivision.select([:id_division, :parent_id, :division, :code_division]).where("id_division=?", params[:id])
    @department = @subdivisions[0]
    if @department.parent_id
      @maindivision = Subdivision.select([:division]).where("id_division =?", @department.parent_id).first
    end
  end
end