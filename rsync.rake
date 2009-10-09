# Sir-Du-Bob Rake Tasks By Peter Boling
# License: MIT
# Copyright: 2007-2009 Peter Boling
# Contact: peter dot boling at gmail dot com

namespace :rsync do
  
  desc "rsync db dump file over ssh (secure!). Can also run with ENV=xxxx"
  task :db => :environment do
    @env = RAILS_ENV

    @help_text = "
HELP        - Usage: HELP=true
            Displays this helpful information!
                      
RAILS_ENV   - Usage: RAILS_ENV=environment
            Where environment is one of: development, production, test, etc
            Default: current env of shell (development is default if none specified in ~/.bash*)
  
VERBOSE     - Usage: VERBOSE=true
            Sets verbosity of output
            Default: false (if not provided)

DBHOST      - Usage: DBHOST=true
            Use specified host instead of host for ENV in database.yml
            Default: host for ENV in database.yml (if not provided)

DBUSER      - Usage: DBUSER=some_username
            Use specified username instead of username for RAILS_ENV in database.yml
            Default: username for RAILS_ENV in database.yml (if not provided)

RUN         - Usage: RUN=true
            Actually run the commands (otherwise they are displayed only)
            Default: true (if not provided)

FILE    - Usage: FILE=true
            Save dump to FILE
            Default: {ENV}-data-#{Date.today}.sql.gz (if not provided)

ZIP         - Usage: ZIP=true
            Sets if we zip up the sql dump or not
            Default: true (if not provided)
            Ignored if FILE is also provided as a parameter

REMOTE_PATH - Usage: REMOTE_PATH=/var/www/apps/stuff/schema/dumps

LOCAL_PATH  - Usage: LOCAL_PATH=/var/www/apps/stuff/schema/dumps
            Default: cwd/schema/dumps/"
  
    # output HELP in man cases, or if env | remote_path is not specified
    @remote_path = ENV['REMOTE_PATH']
    @local_path = ENV['LOCAL_PATH'] || `pwd`.strip + '/schema/dumps'
    @zip = !( ENV['ZIP'] && ENV['ZIP'] == 'false')

    if (ENV['HELP'] || !@env || !@remote_path)
      puts @help_text
      abort
    end

    @verbose = ( ENV['VERBOSE'] && ENV['VERBOSE'] == 'true')
    @run = !( ENV['RUN'] && ENV['RUN'] == 'false')

    get_db_info(@env, @verbose)
    get_file_name(@env, @zip)

    @db_host = (ENV['DBHOST'] ? ENV['DBHOST'] : @db_host)
    @db_user = (ENV['DBUSER'] ? ENV['DBUSER'] : @db_user)
    @db_file = (ENV['FILE'] ? ENV['FILE'] : @db_file)

    dump_file = "#{@local_path}/#{@db_file}"

    unless File.exists?(dump_file)

      rsync_exe = 'rsync -av -e ssh'
  
      #make sure we have a spot for the dump to go
      begin
        puts "Creating Dir: #{@local_path}..." if @verbose
        `mkdir -p #{@local_path}` if @run
      rescue
        puts "unable to create directory: #{@local_path}"
      end
      
      rsync_command = "#{rsync_exe} #{@db_host}:#{@remote_path}/#{@db_file} #{@local_path}"
      if @db_host != 'localhost'
        puts "Rsync command:\n#{rsync_command} \nHit enter to continue...."; STDIN.gets
        if @run
          puts "rsyncing to local machine now... \n#{dump_file}" if @verbose
          sh(rsync_command)
        else
          puts "Skipping rsync to local machine. \n#{dump_file}" if @verbose
          puts "Reason:\nRUN=false"
        end
      else
        puts "Rsync cancelled:\n#{rsync_command}"
        puts "Reason:\nNot running, as host is localhost"
      end
    else
      puts "Rsync cancelled."
      puts "Reason:\nFile #{dump_file} already exists"
    end

    puts "Done." if @verbose
  
  end

end
