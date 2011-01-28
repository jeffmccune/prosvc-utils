# This application is for catalog diffs 
# it should be able to do a diff between catalogs or
# directories filled with catalogs
# this is mostly a port of Ari's code
require 'puppet/application'
require 'yaml'
require 'pp'

class Puppet::Application::Diff < Puppet::Application
  # do I need to parse the config?
  should_parse_config
  #run_mode :master

  # do some initialization before arguments are processed
  def preinit 
    trap(:INT) do
      $stderr.puts "Cancelling Tests"
      exit(0)
    end
    {
      # this is where the diffs will go
      :outputdir => "#{Puppet[:vardir]}/tests/",
      # set log levels
      :verbose => false,
      :debug => false
    }.each do |opt, value|
      options[opt]=value
    end
  end
  #  "directory to output yaml catalogs",
  option('--outputdir DIR') do |args|
    options[:outputdir]=args
  end
  # TODO : these may not be required in 2.7.x
  option('--verbose', '-v')
  option('--debug', '-d')

  # do some setup after options are set
  def setup 
    # there must be something to setup
    @from=command_line.args.shift
    @to=command_line.args.shift
  end

  # main method
  def run_command
    [@from, @to].each do |r|
      unless File.exist?(r)
        raise Puppet::Error, "File #{r} does not exist"
      end
      from = YAML.load(File.read(@from))
      to = YAML.load(File.read(@to))
      titles = {}
      titles[:to] = extract_titles(to)
      titles[:from] = extract_titles(from)
      puts "Resource counts:"
      puts "\tOld: #{titles[:from].size}"
      puts "\tNew: #{titles[:to].size}"

      if titles[:from].size > titles[:to].size
        puts "Resources not in new catalog"
        print_resource_diffs(titles[:from], titles[:to])
      elsif titles[:to].size > titles[:from].size
        puts "Resources not in old catalog"
        print_resource_diffs(titles[:to], titles[:from])
      else
        puts "Catalogs contain the same resources by resource title"
      end
      compare_resources(from, to)
    end
  end
end
