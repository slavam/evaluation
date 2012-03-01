class ApplicationController < ActionController::Base
  helper :all
  protect_from_forgery
  helper_method :current_user_session, :current_user

#  audit Factor, Block

  around_filter :set_audit_user

  protected

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  private
  def set_audit_user
    Audit.as_user current_user do
      yield
    end
  end

  def store_location
    session[:return_to] = request.request_uri
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end


  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def require_user
    unless current_user
#      store_location
      flash_error 'require_user'
      redirect_to new_user_session_url
      return false
    end
  end

  def require_no_user
    if current_user
#      store_location
      flash_error 'require_no_user'
      redirect_to profile_url
      return false
    end
  end
  
  def require_admin
    require_user
    if current_user
      unless current_user.admin?
        flash_error 'require_admin'
        redirect_to profile_url
        return false
      end
    end
  end

  
  def notice_created
    flash_notice 'created'
  end

  def notice_updated
    flash_notice 'updated'
  end

  def notice_destroyed
    flash_notice 'destroyed'
  end

  def flash_notice(key)
    flash[:notice] = translate_controller key
  end

  def flash_error(key)
    flash[:error] = translate_controller key
  end
  
  def translate_controller(key)
    name = controller_name.singularize
    translation_opts = { :raise => true }
    I18n.translate "flash.#{name}.#{key}", translation_opts
  rescue I18n::MissingTranslationData => e
    I18n.translate "flash.#{key}", translation_opts.merge(:name => name.humanize)
  end
  
end
