class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  
  def new
    @user_session = UserSession.new
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      notice_created
      redirect_to :controller => 'performances', :action => 'get_report_params'
    else
      flash_error 'auth_error'
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy
    notice_destroyed
    redirect_back_or_default new_user_session_url
  end
end
