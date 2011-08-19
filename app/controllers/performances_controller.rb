# coding: utf-8
class PerformancesController < ApplicationController
  ORACLE_OWNER = 'RPK880508'
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end

  def show_values
    @values = Performance.where("division_id=? and direction_id=? and factor_id=?",
      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
  end
    
  def get_report_params
  end

  def get_calc_params
  end

  def calc_kpi
    get_plan params[:report_params][:period_id], params[:report_params][:division_id], params[:report_params][:direction_id] 
    redirect_to :action => :show_report, :report_params => {:period_id =>    params[:report_params][:period_id], 
                                                            :division_id =>  params[:report_params][:division_id], 
                                                            :direction_id => params[:report_params][:direction_id]}
  end
    
  def show_report
    get_actual_performances params[:report_params][:period_id], params[:report_params][:division_id], params[:report_params][:direction_id]
    if @performances.size == 0
      flash_error :kpi_not_ready
      redirect_to :action => 'get_report_params'
    end
  end
  
  def report_print
    get_actual_performances params[:period_id], params[:division_id], params[:direction_id]
    output = Report1.new(:page_size => "A4", :page_layout => :landscape, :margin => 20).to_pdf @performances 

    respond_to do |format|
      format.pdf do
        send_data output, :filename => "report1.pdf", :type => "application/pdf", :format => 'pdf'
      end
    end
  end
  
  private
  
  def get_plan period_id, division_id, direction_id
    r =  division_id > '9' ? division_id : ('0'+division_id)
    Factor.find_by_sql("select f.id factor_id, a.name article from factors f
      join articles a on a.factor_id=f.id
      where block_id in
        (select id from blocks where direction_id="+direction_id.to_s+")").collect { |e|
# this is wery hard code!
      if e.article[0,2] == 'BP'    
        s = "select mes"+period_id+" plan from "+ORACLE_OWNER+".bp_sprav s join "+ORACLE_OWNER+".bp_0"+r+
          " bp on s.id = bp.id_sprav where s.namepp = '"+e.article+"'"
      else
        m = Period.find(period_id).start_date.strftime("%m").to_i
        ss = ''
        i = 0
        ss = ss+"plan_#{i+=1}+" while i<m
        ss = ss[0, ss.length-1]
        s = "select "+ss+" plan from "+ORACLE_OWNER+".rezult_0"+r+" rs join "+ORACLE_OWNER+
          ".directory d on d.id = rs.id_directory and d.namepp = '"+e.article+"'"
      end    
      @plan = PlanDictionary.find_by_sql(s).last
      @performance = Performance.where("period_id=? and division_id=? and direction_id=? and factor_id=?",
        period_id, division_id, direction_id, e.factor_id).last
      if @performance
        @performance.plan = @plan.plan
        @performance.calc_date = Time.now
        @performance.save
      end
#      p @plan.attributes.size.to_s+"++++++++++++++++"
# column_names      
#      p PlanDictionary.columns_hash.size.to_s+">>>>>>>>>>>>>>>>>>>>"
#      @fact = PlanDictionary.find_by_sql("select * from RPK880508.rezult_003 r
#        join rpk880508.directory d on d.id = r.id_directory and d.namepp = 'п00.00.05.01.00.00'").last
#      p @fact.attributes.sort.to_s+">>>>>>>>>>>>>>>>>>>>"
    }
  end
  
  def get_actual_performances period_id, division_id, direction_id
    @performances = Performance.where("period_id=? and division_id=? and direction_id=?",
      period_id, division_id, direction_id).order(:block_id, :factor_id)
#    @performances = Performance.find_by_sql("SELECT p.*, wf.weight weight_factor 
#      from performances p
#      join weight_factors wf on wf.direction_id = p.direction_id and wf.factor_id=p.factor_id
#      where division_id="+division_id.to_s+
#      " and p.period_id="+period_id.to_s+
#      " and p.direction_id="+direction_id.to_s+ 
#      " order by block_id, factor_id")
  end
end