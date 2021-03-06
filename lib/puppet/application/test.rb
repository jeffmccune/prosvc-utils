# NOTE - should I call to_ral on the catalogs? what is the difference
# between a resource vs. ral catalog?
# TODO - read Nan's code, noop needs to ignore execs with unless/onlyif
# NOTE - maybe Puppet[:manifest] should be unset when using Puppet[:code]
# TODO - make sure the facts and node serialization stuff works with environments
# TODO - add more unit tests
# TODO - I should allow filters of which nodes we are going to apply
#   - awesome sauce!!
# TODO - we should probably warn if the outputdir exists?
#

# This script takes a node name and a directory to output the compiled
# catalogs, the compiles the defined catalog if it does not already exist
# unless --force is specified.
#
# It also optionally can override the defaults with a specified manifest, 
# modulepath, and yamldir.

#
# in order to run as non-root, you may have to set
#   statedir, and vardir
#

require 'puppet/application'
require 'puppet/tools/compile'
require 'puppet/tools/catalog'
require 'find'

class Puppet::Application::Test < Puppet::Application
  include Puppet::Tools::Compile
  include Puppet::Tools::Catalog
  should_parse_config
  # TODO what does this do?
  run_mode :master


  def help
    puts '
 
= Synopsis

A Puppet appliction for compiling catalogs.
 
= Usage

   puppet test [-d|--debug] [-v|--verbose] [--outputdir]
   puppet test --check_tests [--modulepath MP]
   puppet test --compile_tests [--run_noop] [--modulepath MP]
   puppet test --test_nodes NODES [--node_type (facts|node)] [--modulepath MP]

= Description

This is used to compile catalogs for testing (maybe for other reasons later)

= Options

 check_tests:: checks your current modulepath for any manifests that do not
    have corresponding test. prints a list of manifests missing test and returns 1.

 compile_tests:: iterates though all module tests and generates a catalog for
    each one in outputdir. By default uses facter to find facts for compilation.

 test_nodes:: prints a catalog for a given node.

 node_type:: used together with test_nodes, rather the node should be deserialized
    from a node or facts yaml. Located the yaml in Puppet[:yamldir]

 debug::
   Enable full debugging.

 verbose::
 Enable verbosity.
 
= Author
  
 Dan Bode
 
= Copyright
 
  Copyright (c) 2011 Puppet Labs, LLC
  Licensed under the GPL v 2
 '
  end

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
      :node_type => 'node',
      # puppet related config
      :modulepath => nil,
      # set log levels
      :verbose => false,
      :debug => false
    }.each do |opt, value|
      options[opt]=value
    end
    # try to allow running as non-root
    Puppet[:vardir] = ENV['HOME']
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
    raise Puppet::ArgumentError unless args =~ /(node|facts)/
    options[:node_type]=args
  end

  option('--modulepath MP') do |args|
    options[:modulepath]=args
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
    @env = Puppet::Node::Environment.new(Puppet['environment'])
    if options[:modulepath]
      @modulepath = options[:modulepath]
      Puppet[:modulepath] = @modulepath
    else
      @modulepath = @env[:modulepath]
      Puppet[:modulepath] = @modulepath
    end
    if options[:manifest]
      @manifest = options[:manifest]
    else
      @manifest = @env[:manifest]
    end
  end

  # main method
  def run_command
    exit_code=0
    if options[:check_tests]
      size = check_tests(@modulepath).each do |name|
        Puppet.warning("#{name} is missing tests")
      end.size
      exit_code = 1 if size > 0
    end
    if options[:compile_tests]
      testnames = compile_tests
      Puppet.debug "Compile test results: #{testnames.compact.inspect}"
      exit_code = 1 if testnames.include?(nil)
      if options[:run_noop]
        statuses = noop_tests(testnames.compact)
        exit_code = 1 if statuses.include?('failed')
      end  
    end
    # creates nodes based on the serialized facts.
    if options[:test_nodes]
      node_list=nil
      if options[:test_nodes] == :all
        node_list = get_all_nodes(options[:node_type])
      else
        node_list = match_nodes(options[:test_nodes], options[:node_type])
      end
      node_list.each do |node|
        compile_loaded_node(node, options[:outputdir])
      end
    end
    exit(exit_code)
  end

  # for all modules in the modulepath, returns a list of manifests that
  # do not have corresponding tests
  #  this assmes one class or defined resouce type per file
  def check_tests(modulepath)
    tests = []
    manifests =[]
    modulepath.split(':').each do |path|
      path.gsub!(/\/$/, '')
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
    testnames=build_fake_manifest(@modulepath)
    # iterate though all of the node names that present the tests
    testnames.collect do |node_name|
      compile_new_node(node_name, options[:factnode], options[:outputdir])
    end
  end

  # iterates through testnames, and applies catalogs in outputdir
  # in noop mode
  # TODO - filter out catalogs that have execs with onlyif,unless
  # returns the status of each run
  def noop_tests(testnames)
    testnames.collect do |catalogfile|
      catalog = load_catalog(catalogfile, 'pson')
      catalog = catalog.to_ral
      Puppet[:noop] = true

      require 'puppet/configurer'
      configurer = Puppet::Configurer.new
      begin
        #status = configurer.run(:skip_plugin_download => true, :catalog => catalog).status
        #Puppet.info("#{catalogfile} nooo apply result: #{status} ")
        Puppet[:pluginsync] = false
        status = configurer.run( :catalog => catalog)
        'foo'
      rescue
        Puppet.err("Exception when noop running catalog #{$!}")
        'failed'
      end
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
    Puppet.debug(Puppet[:code])
    nodes
  end
end
