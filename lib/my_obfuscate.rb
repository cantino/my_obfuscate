require 'jcode' if RUBY_VERSION < '1.9'
require 'digest/md5'
require 'ffaker'
require 'walker_method'

# Class for obfuscating MySQL dumps. This can parse mysqldump outputs when using the -c option, which includes
# column names in the insert statements.
class MyObfuscate
  attr_accessor :config, :globally_kept_columns, :fail_on_unspecified_columns, :database_type, :scaffolded_tables

  NUMBER_CHARS = "1234567890"
  USERNAME_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_" + NUMBER_CHARS
  SENSIBLE_CHARS = USERNAME_CHARS + '+-=[{]}/?|!@#$%^&*()`~'

  # Make a new MyObfuscate object.  Pass in a configuration structure to define how the obfuscation should be
  # performed.  See the README.rdoc file for more information.
  def initialize(configuration = {})
    @config = configuration
    @scaffolded_tables = {}
  end

  def fail_on_unspecified_columns?
    @fail_on_unspecified_columns
  end

  def database_helper
    if @database_helper.nil?
      if @database_type == :sql_server
        @database_helper = SqlServer.new
      elsif @database_type == :postgres
        @database_helper = Postgres.new
      else
        @database_helper = Mysql.new
      end
    end

    @database_helper
  end

  # Read an input stream and dump out an obfuscated output stream.  These streams could be StringIO objects, Files,
  # or STDIN and STDOUT.
  def obfuscate(input_io, output_io)
    database_helper.parse(self, config, input_io, output_io)
  end

  # Read an input stream and dump out a config file scaffold.  These streams could be StringIO objects, Files,
  # or STDIN and STDOUT.
  def scaffold(input_io, output_io)
    database_helper.generate_config(self, config, input_io, output_io)
  end

  def reassembling_each_insert(line, table_name, columns, ignore = nil)
    output = database_helper.rows_to_be_inserted(line).map do |sub_insert|
      result = yield(sub_insert)
      result = result.map do |i|
        database_helper.make_valid_value_string(i)
      end
    end
    database_helper.make_insert_statement(table_name, columns, output, ignore)
  end

  def extra_column_list(table_name, columns)
    config_columns = (config[table_name] || {}).keys
    config_columns - columns
  end

  def check_for_defined_columns_not_in_table(table_name, columns)
    missing_columns = extra_column_list(table_name, columns)
    unless missing_columns.length == 0
      error_message = missing_columns.map do |missing_column|
        "Column '#{missing_column}' could not be found in table '#{table_name}', please fix your obfuscator config."
      end.join("\n")
      raise RuntimeError.new(error_message)
    end
  end

  def missing_column_list(table_name, columns)
    config_columns = (config[table_name] || {}).keys
    columns - (config_columns + (globally_kept_columns || []).map {|i| i.to_sym}).uniq
  end

  def check_for_table_columns_not_in_definition(table_name, columns)
    missing_columns = missing_column_list(table_name, columns)
    unless missing_columns.length == 0
      error_message = missing_columns.map do |missing_column|
        "Column '#{missing_column}' defined in table '#{table_name}', but not found in table definition, please fix your obfuscator config."
      end.join("\n")
      raise RuntimeError.new(error_message)
    end
  end

  def obfuscate_bulk_insert_line(line, table_name, columns, ignore = nil)
    table_config = config[table_name]
    if table_config == :truncate
      ""
    elsif table_config == :keep
      line
    else
      check_for_defined_columns_not_in_table(table_name, columns)
      check_for_table_columns_not_in_definition(table_name, columns) if fail_on_unspecified_columns?
      # Note: Remember to SQL escape strings in what you pass back.
      reassembling_each_insert(line, table_name, columns, ignore) do |row|
        ConfigApplicator.apply_table_config(row, table_config, columns)
      end
    end
  end

end

require 'my_obfuscate/copy_statement_parser'
require 'my_obfuscate/insert_statement_parser'
require 'my_obfuscate/config_scaffold_generator'
require 'my_obfuscate/mysql'
require 'my_obfuscate/sql_server'
require 'my_obfuscate/postgres'
require 'my_obfuscate/config_applicator'
