class ApplicationController < ActionController::Base
  protect_from_forgery
  private
  class ::String
    require 'iconv'
    
        #
        # Return an utf-8 representation of this string.
        #
    def to_utf
      begin
        Iconv.new("utf-8", "cp1251").iconv(self)
        rescue Iconv::IllegalSequence => e
          STDERR << "!! Failed converting from UTF-8 -> cp1251 (#{self}). Already the right charset?"
        self
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
