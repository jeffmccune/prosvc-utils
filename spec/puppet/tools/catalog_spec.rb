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
    @host1 = 'host{bob: ensure => present, host_aliases => [1,2,3]}'
    @host2 = 'host{bob: ensure => present, host_aliases => [1,2,3,4]}'
    @host3 = 'host{bob: ensure => present, host_aliases => [3,2,1]}'
  end

  describe 'when getting a catlogs resources' do
    it 'should not return containers' do
      resources = get_resources(@catalog, :to_ral => true) 
      resources[["Notify", "name"]][:name].should == "name"
      resources[["Notify", "bar"]][:name].should == "bar"
      resources[["Node", "default"]].should be_nil
      resources[["Bar", "name"]].should be_nil
    end
    it 'should return containers if :to_ral => false' do
      resources = get_resources(@catalog) 
      code = "#{@code_foo_class}\n#{@code_include_foo}\n#{@code_default_node}"
      code << "\n#{@code_define_bar}"
      code << "\n#{@code_declare_bar}"
      catalog =  code_to_catalog(code, 'foonode', {'one'=>'1'})
      resources = get_resources(catalog, :to_ral => false) 
      resources[["Notify", "name"]][:name].should == "name"
      resources[["Notify", "bar"]][:name].should == "bar"
      resources[["Class", "foo"]].should_not be_nil
      resources[["Node", "default"]].should_not be_nil
      resources[["Bar", "name"]][:name].should == 'name'
    end
    it 'should be able to convert 0.25.x catalog'
  end
  describe 'when taking catalog diffs' do
    before :each do
      @foo_class1 = 'class foo1{notify{bar:message => baz}} include foo1'
      @foo_class2 = 'class foo2{notify{bar:message => baz2}} include foo2'
      @hash_code1 = '
class foo($foo={}){notify{bar:message => $foo}}
class { foo: foo => {foo => bar, bar => baz}}'
      @hash_code2 = '
class foo($foo={}){notify{bar:message => $foo}}
class { foo: foo => {foo => bar, bar => bazzer}}'
      @file1 = 'file{"/tmp/foo": mode => 777, owner => root, recurse => true}'
      @file2 = 'file{"/tmp/foo": mode => 664, owner => root, group => sysadm, recurse => true}'
      @service1 = 'service{foo: enable => true}'
      @service2 = 'service{foo: enable => false}'
    end
    it 'should print ral diffs when :to_ral => true' do
      code1 = "#{@foo_class1} #{@file1}"
      code2 = "#{@foo_class2} #{@service1}"
      cat1 = code_to_catalog(code1, 'node1')  
      cat2 = code_to_catalog(code2, 'node2')  
      diff = get_catalog_diffs(cat1, cat2, :to_ral => true)
      diff.title_diffs[:old].should == [['File', '/tmp/foo']]
      diff.title_diffs[:new].should == [['Service', 'foo']]
      diff.title_diffs[:both].should == [['Notify', 'bar']]
      # I would rather use =~, but it fails if they are ==
      diff.resource_diffs[["Notify", "bar"]][:old].should ==
           {:name=>"bar", :message=>"baz", :withpath=>:false, :loglevel=>:notice}
      diff.resource_diffs[["Notify", "bar"]][:new].should ==
           {:name=>"bar", :message=>"baz2", :withpath=>:false, :loglevel=>:notice}
      diff.count_diffs.should == 3
      diff.get_title_diff_array.should ==
        [["The following are only in old catalog", "  - File[/tmp/foo]"],
         ["The following are only in new catalog", "  - Service[foo]"]]
      diff.to_s.should == 
'-------
The following are only in old catalog | The following are only in new catalog
  - File[/tmp/foo]                    |   - Service[foo]

-------
Old Resource:           | New Resource:
  notify{"bar":         |   notify{"bar":
     name => bar        |      name => bar
     message => baz     |      message => baz2
     withpath => false  |      withpath => false
     loglevel => notice |      loglevel => notice
  }                     |   }
'
    end

    it 'should print all resource diffs' do
      code1 = "#{@foo_class1} #{@file1}"
      code2 = "#{@foo_class2} #{@service1}"
      cat1 = code_to_catalog(code1, 'node1')  
      cat2 = code_to_catalog(code2, 'node2')  
      diff = get_catalog_diffs(cat1, cat2)
      diff.title_diffs[:new].should =~ [['Service', 'foo'], ['Class', 'foo2']]
      diff.title_diffs[:old].should =~ [['File', '/tmp/foo'], ['Class', 'foo1']]
      diff.resource_diffs[['Notify', 'bar']][:old].should ==
        {:name=>"bar", :message=>"baz"}
      diff.resource_diffs[['Notify', 'bar']][:new].should ==
        {:name=>"bar", :message=>"baz2"}
      diff.count_diffs.should == 5
    end
    it 'should detect array differences' do
      cat1 = code_to_catalog(@host1, 'node1')
      cat2 = code_to_catalog(@host2, 'node2')
      diff = get_catalog_diffs(cat1, cat2)
      diff.title_diffs[:new].should == []
      diff.title_diffs[:old].should == []
      diff.resource_diffs[["Host", "bob"]][:old].should ==
           {:name=>"bob",
            :host_aliases=>["1", "2", "3"],
            :ensure=>'present'}
      diff.resource_diffs[["Host", "bob"]][:new].should ==
           {:name=>"bob",
            :host_aliases=>["1", "2", "3", "4"],
            :ensure=>'present'}
      diff.count_diffs.should == 1
    end
    it 'should detect hash differences' do
      cat1 = code_to_catalog(@hash_code1, 'node1')  
      cat2 = code_to_catalog(@hash_code2, 'node2')  
      diff = get_catalog_diffs(cat1, cat2)
    end
  end
  describe 'when processing catalogs' do
    before :each do
      @outdir = tmpdir('catalog')
      @cat1 = code_to_catalog(@host1, 'node1')
      @catfile1 = "#{@outdir}/catalog1.yaml"
      File.open(@catfile1, "w") { |catalog|
        catalog.write(format_catalog(@cat1, 'yaml'))
      }
      @cat2 = code_to_catalog(@host1, 'node1')
      @catfile2 = "#{@outdir}/catalog2.pson"
      File.open(@catfile2, "w") { |catalog|
        catalog.write(format_catalog(@cat2, 'pson'))
      }
    end
    it 'should extract titles' do
      extract_titles(@cat1).should =~ ["Host[bob]", "Class[main]", "Stage[main]", "Class[settings]"]
    end
    it 'should abstract ral resources' do
      extract_titles(@cat1, :to_ral => true).should == ["Host[bob]"]
    end
    it 'should be able to load and compare yaml to pson catalogs' do
      diffs = get_catalog_file_diffs(@catfile1, @catfile2)
      diffs.to_s.should == 'No Differences'
      diffs.count_diffs.should == 0
    end
  end
end
