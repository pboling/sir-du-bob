# Sir-Du-Bob Rake Tasks By Peter Boling
# License: MIT
# Copyright: 2007-2009 Peter Boling
# Contact: peter dot boling at gmail dot com

namespace :db do
  
  desc "Dumps the database into schema/env-data-{date}.sql.gz. Can also run with ENV=xxxx" 
  task :dump => :environment do
    @env = RAILS_ENV 

    @help_text = "
HELP        - Usage: HELP=true
            Displays this helpful information!
                      
RAILS_ENV   - Usage: RAILS_ENV=environment
            Where environment is one of: development, production, test, etc
            Default: current env of shell (development is default if none specified in ~/.bash*)

FILE        - Usage: FILE=/foo/bar/dump.sql
            Save dump to FILE
            Default: {ENV}-data-#{Date.today}.sql (if not provided)

VERBOSE     - Usage: VERBOSE=true
            Sets verbosity of output
            Default: false (if not provided)

CLEAN       - Usage: CLEAN=true
            add scripts to drop/add ALL tables (doesn't affect source DB, only dump output)
            Default: false (if not provided)

DATA       - Usage: DATA=true
            dump all rows from non-excluded tables (doesn't affect source DB, only dump output)
            Default: true (if not provided)

RSYNC       - Usage: RSYNC=true
            Rsync the results back to the local machine using an encrypted connection (rsync over ssh)
            Default: true (if not provided)

DBHOST      - Usage: DBHOST=true
            Use specified host instead of host for ENV in database.yml
            Default: host for ENV in database.yml (if not provided)

DBUSER      - Usage: DBUSER=some_username
            Use specified username instead of username for RAILS_ENV in database.yml
            Default: username for RAILS_ENV in database.yml (if not provided)

PASS_PROMPT - Usage: PASS_PROMPT=true
            Should prompt for password or use the one in the database.yml?
            Default: true (so that passwords aren't left in command histories and
              so that passwords that cannot be sent as params can be used.)

RUN         - Usage: RUN=true
            Actually run the commands (otherwise they are displayed only)
            Default: true (if not provided)

LOCAL_PATH  - Usage: LOCAL_PATH=/var/www/apps/stuff/schema/dumps

ENCODING    - Usage: ENCODING=utf8, or ENCODING=latin1, etc
            Default: encoding for ENV in database.yml, or if that's nil then utf8 (if not provided)

EXCLUDE     - Usage: EXClUDE=false
            Use this to INClUDE all tables (even those listed in the script as tables to exclude from the dump).
            Default: true (if not provided)

ZIP         - Usage: ZIP=true
            Sets if we zip up the sql dump or not
            Default: true (if not provided)
            Ignored if FILE is also provided as a parameter
            "

    # output HELP in man cases, or if env is not specified
    if (ENV['HELP'] || !@env)
      puts @help_text
      abort
    end

    @verbose = ( ENV['VERBOSE'] && ENV['VERBOSE'] == 'true')
    @zip = !( ENV['ZIP'] && ENV['ZIP'] == 'false')
    @verbose = ( ENV['VERBOSE'] && ENV['VERBOSE'] == 'true')
    @run = !( ENV['RUN'] && ENV['RUN'] == 'false')
    @pass_prompt = !( ENV['PASS_PROMPT'] && ENV['PASS_PROMPT'] == 'false')
    @clean = (ENV['CLEAN'] && ENV['CLEAN'] == 'true')
    @data = !( ENV['DATA'] && ENV['DATA'] == 'false')
    @exclude = (ENV['EXCLUDE'] && ENV['EXCLUDE'] == 'true')

    get_db_info(@env, @verbose)
    get_file_name(@env, false)
    @db_host = (ENV['DBHOST'] ? ENV['DBHOST'] : @db_host)
    @db_user = (ENV['DBUSER'] ? ENV['DBUSER'] : @db_user)
    @db_file = (ENV['FILE'] ? ENV['FILE'] : @db_file)
    @db_encoding = (ENV['ENCODING'] ? ENV['ENCODING'] : @db_encoding)
    @local_path = ENV['LOCAL_PATH'] || `pwd`.strip + '/schema/dumps'
    
    # tables that are too friggin huge to dump
    excluded_tables = @exclude ? [] : []

    #make sure we have a spot for the dump to go
    begin
      puts "Creating Dir: #{@local_path}..." if @verbose
      `mkdir -p #{@local_path}` if @run
    rescue
      puts "unable to create directory: #{@local_path}"
    end

    dump_file = "#{@local_path}/#{@db_file}"
    
    puts "Dumping to: #{dump_file}" if @verbose

    unless File.exists?(dump_file) || File.exists?(dump_file + '.gz')
      # our executables
      mysqldump_exe = 'mysqldump'
      zip_exe = 'gzip' if @zip
      
      pass = @pass_prompt ? '-p' : "-p\"#{@db_pwd}\""
      
      login_params = "-h #{@db_host} -u #{@db_user} -P #{@db_port} #{pass} #{@db_name}" 
    
      # params for mysqldump
      mysqldump_params = login_params
      mysqldump_params += ' --verbose ' if @verbose
      mysqldump_params += " --default-character-set=#{@db_encoding}" # set the right encoding!
      
      excluded_params = ''
      # remove the unwanted filth
      excluded_tables.each do |ex_table|
         excluded_params += " --ignore-table=#{@db_name}.#{ex_table}"
      end
   
      if @clean
        # params for predump config
        predump_params = mysqldump_params + ' --no-data '
        # do a pre-dump for all drop/create table statements
        cmd = [mysqldump_exe]
        cmd << predump_params
        cmd << "> #{dump_file}"
        predump_command = cmd.flatten.join(' ')
        
        puts "Pre-dump command:\n#{predump_command} \nHit enter to continue...."; STDIN.gets
        puts "Dumping DROP & CREATE statements..." if @verbose && @run
        sh(predump_command) if @run
      end
  
      if @data
        cmd = [mysqldump_exe]
        cmd << mysqldump_params
        cmd << excluded_params
        cmd << '--no-create-info'
        cmd << ">> #{dump_file}"
        mysql_command = cmd.flatten.join(' ')
        
        puts "Dump command:\n#{mysql_command} \nHit enter to continue...."; STDIN.gets
        puts "Dumping all rows from non-excluded tables..." if @verbose && @run
        sh(mysql_command) if @run
      end
      puts "Database dump is at: \n#{dump_file}"
  
      # zip it up, if requested
      if @zip
        zip_command = "#{zip_exe} #{dump_file}"
        puts "Zip command:\n#{zip_command} \nHit enter to continue...."; STDIN.gets
        puts "zipping..." if @verbose && @run
        sh(zip_command) if @run
        puts "Zipped Database dump is at: \n#{dump_file}.gz"
      end
    else
      puts "Dump cancelled."
      puts "Reason:\nFile #{dump_file} already exists"
    end

    puts "Done." if @verbose
  
  end

  desc "Load a db dump into a database. Can also run with ENV=xxxx"
  task :load => :environment do
    @env = RAILS_ENV

    @help_text = "
HELP        - Usage: HELP=true
            Displays this helpful information!
                      
ENV   - Usage: ENV=environment
            Where environment is one of: development, production, test, etc
            Default: none (required)
    
FILE - Usage: FILE=/foo/bar/dump.sql[.gz]
            file to load
            path is relative to cwd, or absolute (/)
            Default:none

ZIP         - Usage: ZIP=true
            Sets if we need to unzip the sql dump or not
            Default: true (if not provided)
            Ignored if FILE is also provided as a parameter

VERBOSE     - Usage: VERBOSE=true
            Sets verbosity of output
            Default: false (if not provided)

RUN         - Usage: RUN=true
            Actually run the commands (otherwise they are displayed only)
            Default: true (if not provided)

DBHOST      - Usage: DBHOST=true
            Use specified host instead of host for ENV in database.yml
            Default: host for ENV in database.yml (if not provided)

DBUSER      - Usage: DBUSER=some_username
            Use specified username instead of username for RAILS_ENV in database.yml
            Default: username for RAILS_ENV in database.yml (if not provided)

PASS_PROMPT - Usage: PASS_PROMPT=true
            Should prompt for password or use the one in the database.yml?
            Default: true (so that passwords aren't left in command histories and
              so that passwords that cannot be sent as params can be used.)"  
            
    @verbose = ( ENV['VERBOSE'] && ENV['VERBOSE'] == 'true')
    @verbose = ( ENV['VERBOSE'] && ENV['VERBOSE'] == 'true')
    @run = !( ENV['RUN'] && ENV['RUN'] == 'false')
    @zip = !( ENV['ZIP'] && ENV['ZIP'] == 'false')
    @pass_prompt = !( ENV['PASS_PROMPT'] && ENV['PASS_PROMPT'] == 'false')

    # output HELP in man cases, or if env is not specified
    if (ENV['HELP'] || !@env)
      puts @help_text
      abort
    end

    get_db_info(@env, @verbose)
    get_file_name(@env, @zip)
    @db_host = (ENV['DBHOST'] ? ENV['DBHOST'] : @db_host)
    @db_user = (ENV['DBUSER'] ? ENV['DBUSER'] : @db_user)
    @db_file = (ENV['FILE'] ? ENV['FILE'] : @db_file)
    @db_encoding = (ENV['ENCODING'] ? ENV['ENCODING'] : @db_encoding)
    @local_path = ENV['LOCAL_PATH'] || `pwd`.strip + '/schema/dumps'
    
    pass = @pass_prompt ? '-p' : "--password=\"#{@db_pwd}\""

    dump_file = "#{@local_path}/#{@db_file}"

    if File.exists?(dump_file)
      mysql_exe = 'mysql'
  
      # do it
      if !@db_file.scan('.gz').empty?
        zip_exe = 'gunzip'
        puts 'unzipping ...'
        zip_command = "#{zip_exe} #{dump_file}"
        puts "Unzip command:\n#{zip_command} \nHit enter to continue...."; STDIN.gets
        puts "Unzipping..." if @verbose && @run
        sh(zip_command) if @run
        dump_file.chomp!(".gz")
      end
  
      # construct our commands
      cmd = [mysql_exe] 
      cmd << "--host='#{@db_host}'" unless @db_host.blank? 
      cmd << "-P #{@db_port}"
      cmd << "--user='#{@db_user}'" 
      cmd << "#{pass}"
      cmd << @db_name 
      cmd << "< #{dump_file}" 
      mysql_command = cmd.flatten.join ' '
      puts "MySQL command:\n#{mysql_command} \nHit enter to continue...."; STDIN.gets
      puts "importing..." if @verbose && @run
      sh mysql_command if @run
    else
      puts "Dump cancelled."
      puts "Reason:\nFile #{dump_file} does not exist"
    end

    puts "Done." if @verbose

  end

end
