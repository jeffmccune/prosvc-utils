require 'puppet'
require 'puppet/tools/compile'
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

describe Puppet::Tools::Compile do
  # load the helper libs from puppet spec
  # done setting up path
  # I dont know how to stub this,
  # should I create fakes dirs or what?
  before :each do 
    @yamldir=tmpdir('facttests') 
    FileUtils.mkdir(File.join(@yamldir, 'facts'))
    FileUtils.mkdir(File.join(@yamldir, 'node'))
    Puppet[:yamldir] = @yamldir
    Puppet[:clientyamldir] = @yamldir
    @factobj = Puppet::Node::Facts.new('fact-daddy', {
      'foo' => 'bar'                      
    })
    @nodeobj = Puppet::Node.new('node-daddy')
    @nodeobj.merge({'foo'=>'bar'})
  end

  describe 'when parsing things from yamldir' do
    describe 'when getting facts' do
      it 'should be able to load facts from yaml' do
        File.open(File.join(@yamldir, 'facts', 'fact-daddy.yaml'), 'w') do |fh|
          fh.write(YAML.dump(@factobj))
        end
        facts = get_facts('fact-daddy') 
        facts[:foo].should == @factobj.values[:foo]
      end
      it 'should raise error if yaml does not exist' do
        lambda do
          get_facts('fact-daddy') 
        end.should raise_error(Puppet::Error, "Could not find yaml facts for fact-daddy")
      end
    end
    describe 'when getting a node' do
      it 'should get from yaml if from :node' do
        File.open(File.join(@yamldir, 'node', 'node-daddy.yaml'), 'w') do |fh|
          fh.write(YAML.dump(@nodeobj))
        end
        node = get_node('node-daddy', :node)
        node.name.should == @nodeobj.name
        node.classes.should == @nodeobj.classes
      end
      it 'should fail if type is set to :node and no node exists' do
        lambda do 
          get_node('node-daddy', :node)
        end.should raise_error(Puppet::Error,'Could not find yaml node for node-daddy')
      end
      it 'should build a new node from facts if type is facts' do
        File.open(File.join(@yamldir, 'facts', 'fact-daddy.yaml'), 'w') do |fh|
          fh.write(YAML.dump(@factobj))
        end
        node = get_node('fact-daddy', :facts)
        node.name.should == 'fact-daddy'
        node.parameters[:foo].should == @factobj.values[:foo]
      end
      it 'should raise error if yaml does not exist' do
        lambda do
          get_node('fact-daddy', :facts) 
        end.should raise_error(Puppet::Error, "Could not find yaml facts for fact-daddy")
      end
    end
    describe 'when getting all pre-existing nodes' do
      before do
        ['one.yaml', 'two.yaml', 'three.foo', 'four.pson'].each do |fn|
          FileUtils.touch("#{@yamldir}/node/#{fn}")
        end
        ['five.yaml', 'six.yaml', 'seven.foo', 'eight.pson'].each do |fn|
          FileUtils.touch("#{@yamldir}/facts/#{fn}")
        end
      end
      it 'should pull any files from yamldir/node/ that match *.yaml' do
        get_all_nodes('node').should =~ ['one', 'two']
      end
      it 'should pull any files from yamldir/facts/ that match *.yaml' do
        get_all_nodes('facts').should =~ ['five', 'six']
      end
      it 'should return [] when noting matches' do
        get_all_nodes('fuj').should =~ []
      end
    end
  end
  describe 'when compiling a nodes catalog' do
    before :each do 
      Puppet[:code]='node node-daddy {notify{$foo:}}'
      @outputdir=tmpdir('catalog_out')
    end
    it "should be able to compile a node" do
      catalog = compile_catalog_for_node(@nodeobj)
      catalog.name.should == 'node-daddy'
      catalog.resource('Notify', 'bar').to_s.should == 'Notify[bar]'
    end
    it 'should compile catalogs to pson from pre-existing nodes' do
      File.open(File.join(@yamldir, 'node', 'node-daddy.yaml'), 'w') do |fh|
        fh.write(YAML.dump(@nodeobj))
      end
      compile_loaded_node('node-daddy', @outputdir)
      data = PSON.parse File.read("#{@outputdir}/node-daddy.pson")
      data.name.should == 'node-daddy'
      data.resource('Notify', 'bar').to_s.should == 'Notify[bar]'
    end
    it 'should compile catalogs to yaml from pre-existing nodes' do
      File.open(File.join(@yamldir, 'node', 'node-daddy.yaml'), 'w') do |fh|
        fh.write(YAML.dump(@nodeobj))
      end
      compile_loaded_node('node-daddy', @outputdir)
      data = PSON.parse File.read("#{@outputdir}/node-daddy.pson")
      data.name.should == 'node-daddy'
      data.resource('Notify', 'bar').to_s.should == 'Notify[bar]'
    end

    it 'should be possible to assign facts from yaml to another node' do
      Puppet[:code]='node nodey {notify{$foo:}}'
      File.open(File.join(@yamldir, 'facts', 'fact-daddy.yaml'), 'w') do |fh|
        fh.write(YAML.dump(@factobj))
      end
      #require 'ruby-debug';debugger
      compile_new_node('nodey', 'fact-daddy', @outputdir, format=:yaml)
      data = PSON.parse File.read("#{@outputdir}/nodey.pson")
      data.name.should == 'nodey'
      data.resource('Notify', 'bar').to_s.should == 'Notify[bar]'
    end
    it 'should be assign facts from facter by default'
  end
end
