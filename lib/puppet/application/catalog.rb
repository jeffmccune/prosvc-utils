# This application is for catalog analysis
# This application should run as a client
require 'puppet/application'
require 'yaml'
require 'pp'

class Puppet::Application::Catalog < Puppet::Application
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
      :format => "yaml",
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
    options[:filename] = args
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
    catalog = load_catalog(file)
    if options[:filter]
      catalog=filter(catalog)
    end
    if options[:summary] 
      catalog_summary(catalog)
    else
      catalog_print(catalog)
    end
  end

  # methods to be moved out of application
  def load_catalog(filename)
    begin
      text = File.read(filename)
      # attempt to load as pson, then attempt to load as yaml
      catalog = Puppet::Resource::Catalog.convert_from(Puppet::Resource::Catalog.default_format,text) if options[:format] == 'pson'
      # catalog = Puppet::Resource::Catalog.pson_create(catalog) unless catalog.is_a?(Puppet::Resource::Catalog)
      catalog = YAML.load(text) unless catalog.is_a?(Puppet::Resource::Catalog) if options[:format] = 'yaml'
    rescue => detail
      raise Puppet::Error, "Could not deserialize catalog from #{options[:format]}: #{detail}"
    end
    #catalog.to_ral 
  end

  def filter(catalog, filter=options[:filter])
    catalog = catalog.vertices.select{|vertex| vertex.type == filter}
  end

  def catalog_summary(catalog)
    puts "Catalog Summary"
    puts "Catalog contains #{catalog.size} resources."
    types = []
    catalog.vertices.each {|vertex| types << vertex.type }
    types.uniq.sort.each do |type|
      puts "  -- #{type} contain #{filter(catalog,type).size} resources."
    end
    #pp catalog
  end

  def catalog_print(catalog)
    if options[:to_manifest]
      #puts catalog.to_resource
      catalog.each do |x|
        puts x.to_manifest
      end
    elsif options[:to_dot]
      #puts catalog.to_dot
      catalog.each do |x|
        pp x.to_dot
      end
    else
      catalog.each do |x|
        puts x.title
      end
    end
  end
end
