#!/usr/bin/env ruby

require 'puppet'
require 'puppet/tools/compile'
require 'puppet/application'
require 'puppet/application/test'
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

describe 'Puppet::Application::Test' do
  before do
    @tester = Puppet::Application[:test]
  end

  it "should ask Puppet::Application to parse Puppet configuration file" do
    @tester.should_parse_config?.should be_true
  end

  it 'should have lots of options'

  it 'should do stuff in pre-init and setup'

  it 'should do stuff in run command'
  describe 'when assigning environments' do

  end
  describe 'when setting up' do

  end
  describe 'when running command' do
    it 'should call check_tests when --check_tests is set' do

    end
    it 'should call compile test if --compile_test is set' do

    end
    it 'should run noop on tests if --run_noop is set'
  end

#  @options.each do |option|
#    it "should declare handle_#{option} method" do
#      @apply.should respond_to("handle_#{option}".to_sym)
#    end
#  end
  describe 'when checking tests' do
    before :each do
      @modules=['bar', 'foo']
      @modulepaths=[]
      2.times do |i|
       @modulepaths.push(tmpdir('fake_manifests'))
       path=@modulepaths.last
       FileUtils.mkdir_p(File.join(path, @modules[i], "manifests"))
       FileUtils.mkdir_p(File.join(path, @modules[i], "tests"))
       File.open(File.join(path, @modules[i], "manifests/init.pp"), 'w') do |fh|
         fh.write("class #{@modules[i]} { notify{$operatingsystem:}}")
       end  
       File.open(File.join(path, @modules[i], "tests/init.pp"), 'w') do |fh|
         fh.write("class {#{@modules[i]}:}")
       end  
      end
    end
    describe 'when building fake manifests' do
      it 'should work with one modulepath' do
        @tester.build_fake_manifest(@modulepaths.first).should == ['bar-init.pp']
        Puppet[:code].should == "node 'bar-init.pp' {\n class {bar:}\n}\n"
      end
      it 'should work with multiple modulepaths' do
        @tester.build_fake_manifest(@modulepaths.join(':')).should == ['bar-init.pp', 'foo-init.pp']
        Puppet[:code].should == "node 'bar-init.pp' {\n class {bar:}\n}\nnode 'foo-init.pp' {\n class {foo:}\n}\n"
      end
      it 'should accept modulepaths with trailing slashes' do
        #require 'ruby-debug';debugger
        @tester.build_fake_manifest(@modulepaths.first+'/').should == ['bar-init.pp']
        Puppet[:code].should == "node 'bar-init.pp' {\n class {bar:}\n}\n"
      end
      it 'should correctly find deeper directory paths' do
        @deepdir=tmpdir('fake_manifest')
        FileUtils.mkdir_p(File.join(@deepdir, 'fooper', 'tests', 'dev'))
        File.open(File.join(@deepdir, 'fooper', "tests/dev/bar.pp"), 'w') do |fh|
          fh.write("class {'fooper::dev::bar':}")
        end
        @tester.build_fake_manifest(@deepdir).should == ['fooper-dev-bar.pp']
        Puppet[:code].should == "node 'fooper-dev-bar.pp' {\n class {'fooper::dev::bar':}\n}\n"
      end
      it 'should not care if a modulepath does not exist' do
        dir = File.join(tmpdir('path'), 'floppydoppy')
        @tester.build_fake_manifest(dir).should == []
      end
    end
    describe 'when checking tests' do
      before :each do
        @modpath=tmpdir('test_modules')
        FileUtils.mkdir_p(File.join(@modpath, 'fooper', 'manifests', 'dev'))
        FileUtils.mkdir_p(File.join(@modpath, 'fooper', 'tests', 'dev'))
      end
      it 'should warn about any manifests missing tests' do
        @tester.check_tests(@modpath).should == []
      end
      it 'should not care if modulepath does not exist' do
        FileUtils.touch(File.join(@modpath, 'fooper', 'manifests', 'dev', 'foo.pp'))
        @tester.check_tests(@modpath).should == ['fooper-dev-foo.pp']
      end
      it 'should work with multiple modulepaths' do
        @modulepaths.each_index do |i|
          #require 'ruby-debug';debugger
          FileUtils.touch(File.join(@modulepaths[i], @modules[i], "manifests", 'blah.pp'))
        end
       @tester.check_tests(@modulepaths.join(':')).should == ['bar-blah.pp', 'foo-blah.pp']
      end
    end
  end
  describe 'when compiling catalogs' do
    before :each do
      # I can set up tons of stuff here, 
      @modulepath1 = tmpdir()
      @modulepath2 = tmpdir()
    end
    it 'should be able to compile catalog'
    it 'should do something if catalogs fail to compile'
    describe 'when running noop tests' do
      it 'should be able to apply catalog' do
        @tester.options.expects(:[]).with(:outputdir).returns('/var/lib/puppet/tests')
        Puppet::Util::Log.newdestination(:console)
        Puppet[:noop] = true
        @tester.noop_tests(['gcc-gcc.pp'])
      end
    end 
  end
end
