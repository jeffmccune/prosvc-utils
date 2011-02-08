require 'puppet'
require 'puppet/tools/parser'

describe 'Puppet::Tools::Parser' do

  before :each do 
    @node_code = ""
    @default_node = 'node default{}'
    @multiline_node = 
'
  node a,b,
    c,
    d {
    
  }
'
    @node_with_code = 'node foo {$bar=blah notify{$bar:}}'
    @regex_node = 'node /a\w?[1-2]/ {}'
    @parser = Puppet::Tools::Parser.new()
    @parser.code=@node_code
  end
  describe 'when parsing puppet code' do
    it 'should parse single node' do
      @parser.code=@default_node
      @parser.parse_nodes().keys.should == ['default']
    end
    it 'should be able to parse a nodes' do
      @parser.code="#{@multiline_node}\n#{@node_with_code}\n#{@default_node}"
      @parser.parse_nodes().keys.should =~ ['a', 'b', 'c', 'd', 'foo', 'default']
    end
    it 'should be able to parse regex' do
      @parser.code=@regex_node
      @parser.parse_nodes.collect { |k,v| v.instance_eval{@name.inspect}}.should =~ ["/a\\w?[1-2]/"]
    end
    #it 'should be able to parse node ast' do
    #  @parser.code=@node_with_code
    #  @parser.get_node_ast
    #end
  end
end
