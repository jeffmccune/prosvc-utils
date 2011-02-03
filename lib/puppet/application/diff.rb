# This application is for catalog diffs 
# it should be able to do a diff between catalogs or
# directories filled with catalogs
# this is started out as a port of Ari's code, but it has gone well beyond this.

# I dont care about 0.24.x
# it needs to be able to support 0.25.x -> 2.6.x (and beyond!!)
require 'puppet/application'
require 'puppet/tools/catalog'
require 'puppet/external/pson/common'
require 'yaml'
require 'pp'

class Puppet::Application::Diff < Puppet::Application
  include PSON
  include Puppet::Tools::Catalog

  # do some initialization before arguments are processed
  def preinit 
    trap(:INT) do
      $stderr.puts "Cancelling Tests"
      exit(0)
    end
    {
      # I will serialize the diffs here.
      :outputdir => "#{Puppet[:vardir]}/tests/",
      :from_format => nil,
      # set log levels
      :verbose => false,
      :show_containers => false,
      :debug => false
    }.each do |opt, value|
      options[opt]=value
    end
  end
  #  "directory to output yaml catalogs",
  option('--outputdir DIR') do |args|
    options[:outputdir]=args
  end
  option('--from_format FROM') do |args|
    options[:from_format]=args
  end
  option('--show_containers')
  # TODO : these may not be required in 2.7.x
  option('--verbose', '-v')
  option('--debug', '-d')

  # do some setup after options are set
  def setup 
    # there must be something to setup
    @from=command_line.args.shift
    @to=command_line.args.shift
    unless @from and @to
      raise ArgumentError, 'must pass 2 catalogs to compare as arguments'
    end
    Puppet::Util::Log.newdestination(:console)
    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    else
      Puppet::Util::Log.level = :notice
    end
  end

  # main method
  def run_command
    exit_return = 0
    exit_return = 1 if get_diffs
    exit(exit_return)
  end

  def get_diffs 
    to_ral = ! options[:show_containers]
    Puppet.notice "Diffing condensed ral catalogs" if to_ral
    @catalog_diffs = get_catalog_file_diffs(@from, @to, :to_ral => to_ral)
    Puppet.notice @catalog_diffs.to_s
    if @catalog_diffs.count_diffs > 0
      Puppet.notice('Catalogs are not the same')
      filename = "#{File.basename(@from)}_#{File.basename(@to)}.yaml"
      write_to_yaml(@catalog_diffs, options[:outputdir], filename)
      @catalog_diffs
    else
      nil 
    end
  end

  def write_to_yaml(diffs, dir, filename)
    # NOTE - not sure if I want to require absolute path
    raise ArgumentError, "invalid outputdir #{dir}" unless dir =~ /\/\w+/
    file = File.join(dir, filename)
    FileUtils.mkdir_p(dir)
    # this yaml dump is lame
    File.open(file, "w") { |fh|
      fh.write YAML::dump(diffs)      
    }
    Puppet.info("wrote diff for to #{file}")
  end
end
