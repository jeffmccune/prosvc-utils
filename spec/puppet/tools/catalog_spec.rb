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
  def code_to_catalog(code, node_name, facts, classes={}) 
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
puts resources.inspect
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
end
