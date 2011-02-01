# This application is for catalog analysis
# This application should run as a client
require 'puppet/application'
require 'puppet/tools/parser'

class Puppet::Application::Parser < Puppet::Application
  should_parse_config

  # do some initialization before arguments are processed
  def preinit 
    @parser = Puppet::Tools::Parser.new()
    trap(:INT) do
      $stderr.puts "puppet catalog: cancelling ..."  
      exit(1)
    end
    {
      # set log levels
      :verbose => false,
      :debug => false,
      :outputdir => "#{Puppet[:vardir]}/nodes/yaml"
    }.each do |opt, value|
      options[opt]=value
    end
  end

  # These have been refactered in 2.6.next
  option('--verbose', '-v')
  option('--debug', '-d')

  option('--file FILENAME') do |args|
    options[:file] = args
  end
  option('--outputdir DIR') do |args|
    options[:outputdir] = args
  end
  option('--get_nodes')
  option('--create_yaml')

  def setup 
    FileUtils.mkdir_p(options[:outputdir]) unless File.exists?(options[:outputdir])
    raise Puppet::Error, 'must specify --file FILENAME to parse' unless options[:file]
  end

  # main method
  def run_command
    @text = File.read(options[:file])
    if options[:get_nodes] 
      @parser.code=@text
      # this will not work well with regex
      nodes = @parser.parse_nodes.keys
      puts "Found the following nodes"
      nodes.each do |node|
        puts node
        filename = File.join(options[:outputdir], "#{node}.yaml")
        puts "Writing file: #{filename}"
        puts "#{filename} already exists" if File.exists?(filename)
        FileUtils.touch(filename)
      end
    else
      raise Puppet::Error, 'can only get nodes, must pass --get_nodes'
    end
  end
end
