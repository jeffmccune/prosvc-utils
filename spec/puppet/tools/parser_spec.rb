require 'puppet'
require 'puppet/tools/parser'

describe 'Puppet::Tools::Parser' do

  before :each do 
    @node_code =
'
  node foo,bar,
      baz {
    $foo="bar"
    notify{$foo:}}
  node bevo{}
  node default{}
'
    @parser = Puppet::Tools::Parser.new()
    @parser.code=@node_code
  end
  describe 'when parsing puppet code' do
    it 'should be able to parse the nodes' do
      @parser.parse_nodes().should =~ ['bar', 'baz', 'bevo', 'default', 'foo']
    end
    it 'should be able to parse node ast' do
      @parser.get_node_ast
    end
  end
end
