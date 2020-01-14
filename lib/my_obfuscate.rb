require 'jcode' if RUBY_VERSION < '1.9'
require 'digest/md5'
require 'ffaker'
require 'walker_method'

# Class for obfuscating MySQL dumps. This can parse mysqldump outputs when using the -c option, which includes
# column names in the insert statements.
class MyObfuscate
  attr_accessor :config, :globally_kept_columns, :database_type, :scaffolded_tables

  NUMBER_CHARS = "1234567890"
  USERNAME_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_" + NUMBER_CHARS
  SENSIBLE_CHARS = USERNAME_CHARS + '+-=[{]}/?|!@#$%^&*()`~'
  COLUMN_MISMATCH_BEHAVIORS = [:fail, :warn, :ignore]

  # Make a new MyObfuscate object.  Pass in a configuration structure to define how the obfuscation should be
  # performed.  See the README.rdoc file for more information.
  def initialize(configuration = {})
    @config = configuration
    @scaffolded_tables = {}
  end

  def errors
    @errors ||= []
  end

  def column_mismatch_behavior
    @column_mismatch_behavior ||= :fail
  end

  def column_mismatch_behavior=(new_behavior)
    if COLUMN_MISMATCH_BEHAVIORS.include?(new_behavior)
      @column_mismatch_behavior = new_behavior
    else
      error_message =
        "#{new_behavior} is not a valid unspecified_columns_behavior. " \
        "Valid options: #{COLUMN_MISMATCH_BEHAVIORS}"

      raise RuntimeError(error_message)
    end
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

    unless missing_columns.empty?
      error_messages = missing_columns.map do |missing_column|
        "Column '#{missing_column}' could not be found in table '#{table_name}', please fix your obfuscator config."
      end

      handle_column_mismatch(*error_messages)
    end
  end

  def missing_column_list(table_name, columns)
    config_columns = (config[table_name] || {}).keys
    columns - (config_columns + (globally_kept_columns || []).map {|i| i.to_sym}).uniq
  end

  def check_for_table_columns_not_in_definition(table_name, columns)
    missing_columns = missing_column_list(table_name, columns)

    unless missing_columns.empty?
      error_messages = missing_columns.map do |missing_column|
        "Column '#{missing_column}' defined in table '#{table_name}', but not found in table definition, please fix your obfuscator config."
      end

      handle_column_mismatch(*error_messages)
    end
  end

  def obfuscate_bulk_insert_line(line, table_name, columns, ignore = nil)
    table_config = config[table_name]
    if table_config == :truncate
      ""
    elsif table_config == :keep
      line
    else
      # Prevents errors with extra columns when not in fail-fast mode.
      table_config = prune_extra_columns(table_name, columns, table_config)

      # Note: Remember to SQL escape strings in what you pass back.
      reassembling_each_insert(line, table_name, columns, ignore) do |row|
        ConfigApplicator.apply_table_config(row, table_config, columns)
      end
    end
  end

  def prune_extra_columns(table_name, columns, table_config)
    extra_columns = extra_column_list(table_name, columns)

    if table_config && !extra_columns.empty?
      table_config.reject { |k,v| extra_columns.include?(k) }
    else
      table_config
    end
  end

  def handle_column_mismatch(*error_messages)
    error_messages.each do |message|
      self.errors << message
    end

    case column_mismatch_behavior
    when :fail
      raise RuntimeError.new(error_messages.join("\n"))
    when :warn
      STDERR.puts(error_messages)
    else
      # Ignore
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
