require 'puppet'
require 'puppet/tools/catalog'
require 'yaml'
require 'puppet/external/pson/common'

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
include PSON

describe 'Puppet::Tools::Catalog' do
  def mkresource(type, name)
    Puppet::Parser::Resource.new(type, name, :source => nil, :scope => @scope)
  end
  def code_to_catalog(code, node_name, facts={}, classes=[]) 
    node = Puppet::Node.new(node_name, :classes => classes)
    node.merge(facts)
    Puppet[:code]=code
    compiled_catalog = Puppet::Resource::Catalog.find(node.name, :use_node=>node)
  end
  def print_catalog(compiled_catalog)
    puts PSON::pretty_generate(
      compiled_catalog,
      :allow_nan => true,
      :max_nesting => false
    ).to_s
  end
  # generating puppet code is the best way to test this
  before :each do 
    @node = Puppet::Node.new("mynode")
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = @compiler.topscope
    @catalog = Puppet::Resource::Catalog.new("host")
    @code_foo_class = 'class foo{notify{bar: message => bo}}'
    @code_include_foo = 'include foo'
    @code_baz_class = "class baz{Notify[baz]->Notify[bar]\nnotify{baz:}}\ninclude baz"
    @code_default_node = 'node default{}'
    @code_define_bar = 'define bar() {notify{$name:}}'
    @code_declare_bar = 'bar{name:}'
    @code = "#{@code_foo_class}\n#{@code_include_foo}\n#{@code_default_node}"
    @code << "\n#{@code_define_bar}"
    @code << "\n#{@code_declare_bar}"
    @code << "\n#{@code_baz_class}"
    @catalog =  code_to_catalog(@code, 'foonode', {'one'=>'1'})
  end

  describe 'when getting a catlogs resources' do
    it 'should not return containers' do
      resources = get_resources(@catalog) 
      resources[["Notify", "name"]][:name].should == "name"
      resources[["Notify", "bar"]][:name].should == "bar"
      resources[["Node", "default"]].should be_nil
      resources[["Bar", "name"]].should be_nil
    end
    it 'should return containers when :show_containers => true' do
      resources = get_resources(@catalog) 
      code = "#{@code_foo_class}\n#{@code_include_foo}\n#{@code_default_node}"
      code << "\n#{@code_define_bar}"
      code << "\n#{@code_declare_bar}"
      catalog =  code_to_catalog(code, 'foonode', {'one'=>'1'})
      resources = get_resources(catalog, :show_containers => true) 
      resources[["Notify", "name"]][:name].should == "name"
      resources[["Notify", "bar"]][:name].should == "bar"
      resources[["Class", "Foo"]].should_not be_nil
      resources[["Node", "default"]].should_not be_nil
      resources[["Bar", "name"]][:name].should == 'name'
    end
  end
  describe 'when taking catalog diffs' do
    before :each do
      @foo_class1 = 'class foo1{notify{bar:message => baz}} include foo1'
      @foo_class2 = 'class foo2{notify{bar:message => baz2}} include foo2'
      @file1 = 'file{"/tmp/foo": mode => 777, owner => root, recurse => true}'
      @file2 = 'file{"/tmp/foo": mode => 664, owner => root, group => sysadm, recurse => true}'
      @service1 = 'service{foo: enable => true}'
      @service2 = 'service{foo: enable => false}'
      @host1 = 'host{bob: ensure => present, host_aliases => [1,2,3]}'
      @host2 = 'host{bob: ensure => present, host_aliases => [1,2,3,4]}'
    end
    it 'should print resoures only in one catalog' do
      code1 = "#{@foo_class1} #{@file1}"
      code2 = "#{@foo_class2} #{@service1}"
      puts code2
      cat1 = code_to_catalog(code1, 'node1')  
      cat2 = code_to_catalog(code2, 'node2')  
      puts get_catalog_diffs(cat1, cat2).to_s
    end
    it 'should print param array differences' do
      cat1 = code_to_catalog(@host1, 'node1')
      cat2 = code_to_catalog(@host2, 'node2')
      get_catalog_diffs(cat1, cat2)
    end
  end
end
