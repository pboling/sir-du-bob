def get_db_info(env, verbose)
  puts "DB settings for #{env}" if verbose
  content = File.read("config/database.yml")
  puts "Found database.yml? #{File.exists?("config/database.yml")}" if verbose
  database_config = YAML.load(content)
  puts "Loading YAML ..." if verbose
  @db = database_config[env]
  puts "Settings: \n" + @db.inspect if verbose
  @db_name =  @db['database']
  @db_host = @db['host'] || 'localhost'
  @db_user =  @db['username']
  @db_pwd =  @db['password']
  @db_port =  @db['port'] || '3306'
  @db_encoding =  @db['encoding'] || 'utf8'
end

def get_file_name(env, zipped = true)
  db_file = "#{env}-data-#{Date.today}.sql"
  @db_file = zipped ? db_file + '.gz' : db_file
end