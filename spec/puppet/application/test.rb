#!/usr/bin/env ruby

require 'puppet'
require 'puppet/tools/compile'
require 'puppet/application/apply'
require 'yaml'

# find all of the puppet spec stuff (more than a little ghetto)
def find_puppet_spec()
  puppetdir = $LOAD_PATH.detect do |file|
    File.directory?(File.join(file, 'puppet')) && 
      File.directory?(File.join(file, '../spec/lib'))
  end
  raise Exception, "could not find puppet spec lib" unless puppetdir 
  $LOAD_PATH.unshift(File.join(puppetdir, '../spec/lib'))
  require File.join(puppetdir, '../spec/spec_helper')
end
find_puppet_spec
require 'puppet_spec/files'
include Puppet::Tools::Compile
include PuppetSpec
include PuppetSpec::Files

describe Puppet::Application::Test do
  before do
    @options = {
                  'factnode'      => 'NODE',
                  #'outputdir'     => 'DIR', 
                  #'run_noop'      => '', 
                  #'check_tests'   => '', 
                  #'compile_tests' => '', 
                  #'test_nodes'    => 'NODES' 
                  #'node_type'     => '', 
                  #'verbose'       => '', 
                  #'debug'         => '',
                  'module_path'   => 'PATH'
               }
    #require 'ruby-debug';debugger
    Puppet::Util::CommandLine.new.require_application('test')
    @app = Puppet::Application.find('test') #.new(self)
  end

  it "should ask Puppet::Application to parse Puppet configuration file" do
    @app.should_parse_config?.should be_true
  end

  @options.each do |option|
    it "should declare handle_#{option} method" do
      @apply.should respond_to("handle_#{option}".to_sym)
    end
  end
end
