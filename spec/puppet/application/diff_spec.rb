#!/usr/bin/env ruby

require 'puppet'
require 'puppet/tools/catalog'
require 'puppet/application'
require 'puppet/application/diff'
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
include Puppet::Tools::Catalog
include PuppetSpec
include PuppetSpec::Files

describe 'Puppet::Application::Diff' do
  before do
    @diff = Puppet::Application[:diff]
  end

  it "should ask Puppet::Application to parse Puppet configuration file" do
    @tester.should_parse_config?.should be_false
  end

  it 'should have lots of options'

  it 'should do stuff in pre-init and setup'

  it 'should do stuff in run command'
  describe 'when assigning environments' do

  end
  describe 'when setting up' do

  end
  describe 'when diffing catalogs' do

    it 'should fail if catalogs are missing'
    it 'should fail if catalog format is not (pson|yaml)'
    it 'should be generally awesome'
    it 'should be able to load catalogs from relative paths'
  end
end
