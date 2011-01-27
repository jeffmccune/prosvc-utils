# NOTE - should I call to_ral on the catalogs? what is the difference
# between a resource vs. ral catalog?
# TODO - read Nan's code, noop needs to ignore execs with unless/onlyif
# NOTE - maybe Puppet[:manifest] should be unset when using Puppet[:code]
# TODO - test with environments (I think it will work)
# TODO - add unit tests
# TODO - I should allow filters of which nodes we are going to apply
#   - awesome sauce!!
# TODO - we should probably warn if the outputdir exists?
#
# TODO - compile tests does not work with environemnts
# when using facts or nodes, I should be able to pass in classes
#

# This script takes a node name and a directory to output the compiled
# catalogs, the compiles the defined catalog if it does not already exist
# unless --force is specified.
#
# It also optionally can override the defaults with a specified manifest, 
# modulepath, and yamldir.

require 'puppet/application'
require 'puppet/tools/compile'
require 'find'

class Puppet::Application::Tester < Puppet::Application
  include Puppet::Tools::Compile
  should_parse_config
  # TODO do I need this?
  run_mode :master

  # do some initialization before arguments are processed
  def preinit 
    trap(:INT) do
      $stderr.puts "Cancelling Tests"
      exit(0)
    end
    {
      :outputdir => "#{Puppet[:vardir]}/tests/",
      #:facts_terminus => 'yaml',
      # options that determine what kind of tests to run
      :run_noop => false,
      # tests directory options
      :compile_tests => false,
      :check_tests => false,
      # this sets factnode for dir tests
      :factnode => 'testnode',
      # tests from yaml
      :test_nodes => nil,
      :node_type => :node,
      # set log levels
      :verbose => false,
      :debug => false
    }.each do |opt, value|
      options[opt]=value
    end
  end
  #  "The name of the node to get facts from, usually the fqdn",
  option('--factnode NODE') do |args|
    options[:factnode]=args
  end
  #  "directory to output yaml catalogs",
  option('--outputdir DIR') do |args|
    options[:outputdir]=args
  end
  # rather or not we should run noop after we compile our 
  # catalogs
  option('--run_noop')
  option('--check_tests')
  option('--compile_tests')

  option('--test_nodes NODES') do |args|
    if args == '--all'
      options[:test_nodes] = :all
    else
      options[:test_nodes] = args.split(',').collect
    end
  end
  option('--node_type TYPE') do |args|
    raise Puppet::ArgumentError unless args =~ /(node|type)/
    options[:node_type]=args
  end
  # TODO : these may not be required in 2.7.x
  option('--verbose', '-v')
  option('--debug', '-d')
  #option('--facts_terminus TERMINUS') do |args|
  #  options[:facts_terminus]=args
  #end
  #option('--modulepath') do args
  #  "rather or not to run the noop tests",
  #  :default => false
  #opt :compile_exclude,
  #  "modules to exclude to compile, noop tests",
  #  :default => ''
  #opt :noop_exclude,
  #  "modules that should not run noop tests",
  #  :defaut => ''

  # do some setup after options are set
  def setup 
    #Puppet::Node::Facts.terminus_class = options[:facts_terminus]
    Puppet[:clientyamldir] = Puppet[:yamldir]
    # Handle the logging settings
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
    if options[:check_tests]
      check_tests(Puppet[:modulepath]).each do |name|
        Puppet.warning("#{name} is missing tests")
      end
    end
    if options[:compile_tests]
      compile_tests
      if options[:run_noop]
        noop_tests(testnames)
      end  
    end
    # creates nodes based on the serialized facts.
    # TODO: 
    if options[:test_nodes]
      node_list=nil
      if options[:test_nodes] == :all
        node_list = get_all_nodes(type)
      else
        node_list = options[:test_nodes]
      end
      node_list.each do |node|
        compile_loaded_node(node, options[:outputdir])
      end
    end
  end

  # for all modules in the modulepath, returns a list of manifests that
  # do not have corresponding tests
  #  this assmes one class or defined resouce type per file
  def check_tests(modulepath)
    tests = []
    manifests =[]
    modulepath.split(':').each do |path|
      Puppet.info("Checking tests for modulepath: #{path}")
      Find.find(path) do |file|
        if file =~ /#{path}\/(\S+)\/tests\/(\S+.pp)$/
          tests.push "#{$1}-#{$2.gsub('/', '-')}"
        elsif file =~ /#{path}\/(\S+)\/manifests\/(\S+.pp)$/
          manifests.push "#{$1}-#{$2.gsub('/', '-')}"
        end
      end
    end
    manifests - tests
  end

  def compile_tests
    # get a single facts cache
    # convert all tests into Puppet[:node]
    # with unique node per test
    # NOTE - this does not work with environments
    testnames=build_fake_manifest(Puppet[:modulepath])
    # iterate though all of the node names that present the tests
    testnames.each do |node_name|
      compile_new_node(node_name, options[:factnode], options[:outputdir])
    end
    testnames
  end

  # iterates through testnames, and applies catalogs in outputdir
  # in noop mode
  # TODO - filter out catalogs that have execs with onlyif,unless
  def noop_tests(testnames)
    testnames.each do |test|
      catalogfile="#{options[:outputdir]}/#{test}"
      # for performance, I would rather make API calls
      # TODO - switch with API calls
      puts `puppet apply --apply #{catalogfile} --preferred_serialization_format yaml --noop`
    end
  end

  # Iterate though all tests in modulepath
  # converts them to sequential node declarations
  # sets this to be Puppet[:code] 
  # the intention is to have a simple program
  # that can compile all tests as quickly as possible
  def build_fake_manifest(modulepath)
    # I shoud make this an instance)
    nodes=[]
    code = ''
    modulepath.split(':').each do |path|
      path.gsub!(/\/$/, '')
      Puppet.info("Compiling tests from modulepath: #{path}")
      Find.find(path) do |file|
        if file =~ /#{path}\/(\S+)\/tests\/(\S+\.pp)$/
          # put ever test in a sequential node declaration
          # accumulate in code string
          testname="#{$1}-#{$2.gsub('/', '-')}"
          nodes.push(testname)
          code << "node '#{testname}' {\n"
          File.readlines(file).each do |line|
            code << " #{line}\n"
          end
          code << "}\n"
        end
      end
    end
    # set all of the code as puppet's code
    Puppet[:code]=code
    nodes
  end
end
