# coding: utf-8
class ActionsController < ApplicationController
  def index
    @actions = Action.order(:name)
  end
  def new
    @action = Action.new
  end
  
  def create
    @action = Action.new params[:action]
    if not @action.save
      render :new
    else
      redirect_to actions_path
    end
  end
  
end