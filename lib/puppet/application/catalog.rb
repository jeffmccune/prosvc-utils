# This application is for catalog analysis
# This application should run as a client
require 'puppet/application'
require 'puppet/tools/catalog'
require 'yaml'
require 'pp'

class Puppet::Application::Catalog < Puppet::Application
  include Puppet::Tools::Catalog
  should_parse_config

  # do some initialization before arguments are processed
  def preinit 
    trap(:INT) do
      $stderr.puts "puppet catalog: cancelling ..."  
      exit(1)
    end
    {
      # set log levels
      :verbose => false,
      :debug => false,
      :format => nil,
    }.each do |opt, value|
      options[opt]=value
    end
  end

  # These have been refactered in 2.6.next
  option('--verbose', '-v')
  option('--debug', '-d')

  # catalog application options
  option('--fetch')
  option('--file FILENAME') do |args|
    options[:file] = args
  end
  option('--format FILEFORMAT') do |args|
    options[:format] = args
  end
  option('--filter STRING') do |args|
    options[:filter] = args
  end
  option('--to_manifest')
  option('--to_dot')
  option('--summary', '-s')

  # do some setup after options are set
  def setup 
    # there must be something to setup
    @from=command_line.args.shift
    @to=command_line.args.shift
  end

  # main method
  def run_command
    file = options[:file] || "#{Puppet[:clientyamldir]}/catalog/#{Puppet[:certname]}.yaml"
    format = options[:format] || get_file_format(file)
    catalog = load_catalog(file, format)
    if options[:filter]
      catalog=filter(catalog, options[:filter].capitalize)
    end
    if options[:summary] 
      catalog_summary(catalog)
    else
      catalog_print(catalog, options)
    end
  end
end
