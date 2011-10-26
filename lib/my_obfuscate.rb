require 'jcode' if RUBY_VERSION < '1.9'
require 'faker'
require 'my_obfuscate/mysql'
require 'my_obfuscate/sql_server'

# Class for obfuscating MySQL dumps. This can parse mysqldump outputs when using the -c option, which includes
# column names in the insert statements.
class MyObfuscate
  attr_accessor :config, :globally_kept_columns, :fail_on_unspecified_columns, :database_type

  NUMBER_CHARS = "1234567890"
  USERNAME_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_" + NUMBER_CHARS
  SENSIBLE_CHARS = USERNAME_CHARS + '+-=[{]}/?|!@#$%^&*()`~'

  # Make a new MyObfuscate object.  Pass in a configuration structure to define how the obfuscation should be
  # performed.  See the README.rdoc file for more information.
  def initialize(configuration = {})
    @config = configuration
  end

  def fail_on_unspecified_columns?
    @fail_on_unspecified_columns
  end

  def database_helper
    if @database_helper.nil?
      if @database_type == :sql_server
        @database_helper = SqlServer.new
      else
        @database_helper = Mysql.new
      end
    end

    @database_helper
  end

  # Read an input stream and dump out an obfuscated output stream.  These streams could be StringIO objects, Files,
  # or STDIN and STDOUT.
  def obfuscate(input_io, output_io)

    # We assume that every INSERT INTO line occupies one line in the file, with no internal linebreaks.
    input_io.each do |line|
      if table_data = database_helper.parse_insert_statement(line)
        table_name = table_data[:table_name]
        columns = table_data[:column_names]
        if config[table_name]
          output_io.puts obfuscate_bulk_insert_line(line, table_name, columns)
        else
          $stderr.puts "Deprecated: #{table_name} was not specified in the config.  A future release will cause this to be an error.  Please specify the table definition or set it to :keep."
          output_io.write line
        end
      else
        output_io.write line
      end
    end
  end

  def reassembling_each_insert(line, table_name, columns)
    output = database_helper.rows_to_be_inserted(line).map do |sub_insert|
      result = yield(sub_insert)
      result = result.map do |i|
        database_helper.make_valid_value_string(i)
      end
      result = result.join(",")
      "(" + result + ")"
    end.join(",")
    database_helper.make_insert_statement(table_name, columns, output)
  end

  def self.row_as_hash(row, columns)
    columns.zip(row).inject({}) {|m, (name, value)| m[name] = value; m}
  end

  def self.apply_table_config(row, table_config, columns)
    return row unless table_config.is_a?(Hash)
    row_hash = row_as_hash(row, columns)

    table_config.each do |column, definition|
      index = columns.index(column)
      
      definition = { :type => definition } if definition.is_a?(Symbol)

      next if definition[:unless] && ((definition[:unless].is_a?(Proc) && definition[:unless].call(row_hash)) || (definition[:unless] == :nil && row[index].nil?))
      next if definition[:if] && ((definition[:if].is_a?(Proc) && !definition[:if].call(row_hash)) || (definition[:if] == :nil && !row[index].nil?))

      if definition[:skip_regexes]
        next if definition[:skip_regexes].any? {|regex| row[index] =~ regex}
      end

      row[index.to_i] = case definition[:type]
        when :email
          random_string(definition[:length] || (4..10), USERNAME_CHARS) + "@example.com"
        when :string
          random_string(definition[:length] || 30, definition[:chars] || SENSIBLE_CHARS)
        when :lorem
          Faker::Lorem.sentences(definition[:number] || 1).join(".  ").gsub(/['"\n\t\r]/, '')
        when :name
          Faker::Name.name.gsub(/['"\n\t\r]/, '')
        when :address
          "#{Faker::Address.street_address}\\n#{Faker::Address.city}, #{Faker::Address.state_abbr} #{Faker::Address.zip_code}".gsub(/['"\n\t\r]/, '')
        when :integer
          random_integer(definition[:between] || (0..1000)).to_s
        when :fixed
          if definition[:one_of]
            definition[:one_of][(rand * definition[:one_of].length).to_i]
          else
            definition[:string].is_a?(Proc) ? definition[:string].call(row_hash) : definition[:string]
          end
        when :null
          nil
        when :keep
          row[index]
        else
          $stderr.puts "Keeping a column value by providing an unknown type (#{definition[:type]}) is deprecated.  Use :keep instead."
          row[index]
      end
    end
    row
  end

  def self.random_integer(between)
    (between.min + (between.max - between.min) * rand).round
  end

  def self.random_string(length_or_range, chars)
    length_or_range = (length_or_range..length_or_range) if length_or_range.is_a?(Fixnum)
    times = random_integer(length_or_range)
    out = ""
    times.times { out << chars[rand * chars.length] }
    out
  end

  def check_for_defined_columns_not_in_table(table_name, columns)
    missing_columns = config[table_name].keys - columns
    unless missing_columns.length == 0
      error_message = missing_columns.map do |missing_column|
        "Column '#{missing_column}' could not be found in table '#{table_name}', please fix your obfuscator config."
      end.join("\n")
      raise RuntimeError.new(error_message)
    end
  end

  def check_for_table_columns_not_in_definition(table_name, columns)
    missing_columns = columns - (config[table_name].keys + (globally_kept_columns || []).map {|i| i.to_sym}).uniq
    unless missing_columns.length == 0
      error_message = missing_columns.map do |missing_column|
        "Column '#{missing_column}' defined in table '#{table_name}', but not found in table definition, please fix your obfuscator config."
      end.join("\n")
      raise RuntimeError.new(error_message)
    end
  end

  def obfuscate_bulk_insert_line(line, table_name, columns)
    table_config = config[table_name]
    if table_config == :truncate
      ""
    elsif table_config == :keep
      line
    else
      check_for_defined_columns_not_in_table(table_name, columns)
      check_for_table_columns_not_in_definition(table_name, columns) if fail_on_unspecified_columns?
      # Note: Remember to SQL escape strings in what you pass back.
      reassembling_each_insert(line, table_name, columns) do |row|
        MyObfuscate.apply_table_config(row, table_config, columns)
      end
    end
  end
end
