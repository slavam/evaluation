require 'bundler/capistrano'
set :application, "kpi"
set :deploy_to, "/var/www/html/#{application}"
set :user, 'morhachov'
set :use_sudo, false

#default_run_options[:pty] = true
#ssh_options[:forward_agent] = true

set :default_environment, {
  'PATH' => "#{deploy_to}/bin:$PATH",
  'GEM_HOME' => "#{deploy_to}/gems" 
}

#set :bundle_cmd, 'source $HOME/.bash_profile && bundle'

set :stack, :passenger

#set :scm, "git"
#set :scm_username, "slavam"
#set :repository, "git://github.com/slavam/evaluation.git"
#set :deploy_via, :remote_cache
set :scm, :none
set :repository, "."
set :deploy_via, :copy
#set :checkout, 'export'

#set :server_name, "web2-d00.adir.vbr.ua"
set :server_name, "web2-d00.adir.vbr.ua"
role :web, server_name                          # Your HTTP server, Apache/etc
role :app, server_name                          # This may be the same as your `Web` server
role :db,  server_name, :primary => true # This is where Rails migrations will run
#role :db,  "your slave db-server here"



# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
  task :restart do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end