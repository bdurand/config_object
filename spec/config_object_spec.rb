require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

module ConfigObject
  class Tester
    include ConfigObject

    attr_reader :value, :object
    attr_accessor :name
    
    def complex
      @complex_called ||= 0
      @complex_called += 1
      @complex
    end
    
    def complex_called
      @complex_called ||= 0
    end
      
    protected
    
    def value= (val)
      @value = val.to_i
    end
    
    def object= (attributes)
      @object = attributes.is_a?(Hash) ? Attributed.new(attributes) : attributes
    end
  end
  
  class Tester2 < Tester
  end
  
  class Attributed
    include ConfigObject::Attributes
    attr_reader :name, :value, :object
    
    def object= (attributes)
      @object = attributes.is_a?(Hash) ? self.class.new(attributes) : attributes
    end
  end
end

describe ConfigObject do
  
  after :each do
    ConfigObject::Tester.clear
    ConfigObject::Tester2.clear
  end
  
  it "should be able to be configured with a hash" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A"},
      :item_b => {:name => "Item B"}
    })
    ConfigObject::Tester['item_a'].name.should == "Item A"
    ConfigObject::Tester[:item_b].name.should == "Item B"
    ConfigObject::Tester['item_c'].should == nil
  end
  
  it "should load configurations from a file" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester['item_1'].name.should == "Item One"
    ConfigObject::Tester[:item_2].name.should == "Item Two"
    ConfigObject::Tester['item_3'].should == nil
  end
  
  it "should load configurations from multiple files overriding values from the first files with those from the later files" do
    ConfigObject::Tester.configuration_files = Pathname.new(File.join(File.dirname(__FILE__), "test_1.yml"))
    ConfigObject::Tester.configuration_files << File.join(File.dirname(__FILE__), "test_2.yaml")
    ConfigObject::Tester['item_1'].name.should == "Item One"
    ConfigObject::Tester[:item_2].name.should == "Item Too"
    ConfigObject::Tester[:item_2].value.should == 2
    ConfigObject::Tester[:item_2].complex.should == "Thing"
    ConfigObject::Tester['item_3'].name.should == "Item Three"
  end
  
  it "should load configurations from directories using the file names as the keys" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml"), File.join(File.dirname(__FILE__), "test_files")
    ConfigObject::Tester[:item_1].name.should == "Item One"
    ConfigObject::Tester[:item_1].value.should == 8
    ConfigObject::Tester[:item_2].name.should == "Item Two" # Not overriddend by item_2.txt
    ConfigObject::Tester[:item_3].name.should == "Item 3 Directory"
    ConfigObject::Tester[:item_3].object.value.should == 10
    ConfigObject::Tester[:item_5].name.should == "Item Five"
  end
  
  it "should load configurations from files only if they exist" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml"), "no_such_file.yaml"
    ConfigObject::Tester['item_1'].name.should == "Item One"
    ConfigObject::Tester[:item_2].name.should == "Item Two"
    ConfigObject::Tester['item_3'].should == nil
  end
  
  it "should evaluate ERB inside configuration files" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_2.yaml")
    ConfigObject::Tester[:item_2].object.should == Date.today
  end
  
  it "should load configuration from files and a hash with the hash taking precedence" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A"},
      :item_1 => {:name => "Item Won"}
    })
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester['item_a'].name.should == "Item A"
    ConfigObject::Tester[:item_1].name.should == "Item Won"
    ConfigObject::Tester[:item_2].name.should == "Item Two"
  end
  
  it "should use default values set in a file for every configuration" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester[:item_1].value.should == 5
    ConfigObject::Tester[:item_2].value.should == 1
  end
  
  it "should let defaults be set manually" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester.set_defaults(:value => 6)
    ConfigObject::Tester[:item_1].value.should == 5
    ConfigObject::Tester[:item_2].value.should == 6
  end
  
  it "should reload the configuration" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester[:item_1].name.should == "Item One"
    ConfigObject::Tester[:item_3].should == nil

    ConfigObject::Tester.configuration_files << File.join(File.dirname(__FILE__), "test_2.yaml")
    ConfigObject::Tester[:item_3].should == nil
    ConfigObject::Tester.reload
    ConfigObject::Tester[:item_1].name.should == "Item One"
    ConfigObject::Tester[:item_3].name.should == "Item Three"
  end
  
  it "should reload automatically when the configuration files are set" do
    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_1.yml")
    ConfigObject::Tester[:item_1].name.should == "Item One"
    ConfigObject::Tester[:item_3].should == nil

    ConfigObject::Tester.configuration_files = File.join(File.dirname(__FILE__), "test_2.yaml")
    ConfigObject::Tester[:item_1].should == nil
    ConfigObject::Tester[:item_3].name.should == "Item Three"
  end
  
  it "should reload automatically when a new configure is called" do
    ConfigObject::Tester.configure({:item_a => {:name => "Item A"}})
    ConfigObject::Tester[:item_a].name.should == "Item A"
    ConfigObject::Tester[:item_b].should == nil

    ConfigObject::Tester.configure({:item_b => {:name => "Item B"}})
    ConfigObject::Tester[:item_a].name.should == "Item A"
    ConfigObject::Tester[:item_b].name.should == "Item B"
  end
  
  it "should reload automatically when the defaults are set" do
    ConfigObject::Tester.configure({:item_a => {:name => "Item A"}})
    ConfigObject::Tester[:item_a].name.should == "Item A"
    ConfigObject::Tester[:item_a].value.should == nil

    ConfigObject::Tester.set_defaults(:value => 14)
    ConfigObject::Tester[:item_a].name.should == "Item A"
    ConfigObject::Tester[:item_a].value.should == 14
  end
  
  it "should notify observers with a callback method or block when the configuration is reloaded" do
    ConfigObject::Tester.configure({:item_a => {:name => "Item A"}})
    
    observer_1 = Object.new
    def observer_1.update_config (config); @updated = config; end
    def observer_1.updated_config?; @updated; end
    ConfigObject::Tester.add_observer(observer_1, :update_config)
    
    observer_2 = Object.new
    observer_2_updated = nil
    ConfigObject::Tester.add_observer(observer_2){|config| observer_2_updated = config}
    
    observer_1.updated_config?.should == nil
    observer_2_updated.should == nil
    ConfigObject::Tester.reload
    observer_1.updated_config?.should == ConfigObject::Tester
    observer_2_updated.should == ConfigObject::Tester
  end
  
  it "should be able to remove observers from being notified" do
    ConfigObject::Tester.configure({:item_a => {:name => "Item A"}})
    
    observer_1 = Object.new
    observer_1_count = 0
    ConfigObject::Tester.add_observer(observer_1){observer_1_count += 1}
    
    observer_2 = Object.new
    observer_2_count = 0
    ConfigObject::Tester.add_observer(observer_2){observer_2_count += 1}
    
    ConfigObject::Tester.reload
    ConfigObject::Tester.remove_observer(observer_1)
    ConfigObject::Tester.reload
    observer_1_count.should == 1
    observer_2_count.should == 2
  end
  
  it "should get the ids of all configuration objects" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A"},
      :item_b => {:name => "Item B"}
    })
    ConfigObject::Tester.ids.sort.should == ["item_a", "item_b"]
  end
  
  it "should be able to find a configuration object by id" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A"},
      :item_b => {:name => "Item B"}
    })
    ConfigObject::Tester.find("item_a").name.should == "Item A"
    ConfigObject::Tester.find(:item_b).name.should == "Item B"
  end
  
  it "should be able to find a configuration object by conditions" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A", :value => 10},
      :item_b => {:name => "Item B"},
      :item_c => {
        :name => "Item C",
        :value => 15,
        :object => {:name => "Item C.1"},
        :complex => [1, 2, 3]
      }
    })
    ConfigObject::Tester.find("name" => "Item A").name.should == "Item A"
    ConfigObject::Tester.find(:name => "Item B").name.should == "Item B"
    ConfigObject::Tester.find(:name => /B/).name.should == "Item B"
    ConfigObject::Tester.find(:value => 15).name.should == "Item C"
    ConfigObject::Tester.find("object.name" => "Item C.1").name.should == "Item C"
    ConfigObject::Tester.find("value.>" => 12).name.should == "Item C"
    ConfigObject::Tester.find("complex.include?" => 1).name.should == "Item C"
    ConfigObject::Tester.find("complex.include?" => 5).should == nil
  end
  
  it "should be able to get all configuration objects" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A"},
      :item_b => {:name => "Item B"}
    })
    ConfigObject::Tester.all.collect{|a| a.name}.should == ["Item A", "Item B"]
  end
  
  it "should be able to get all configuration objects that match some conditions" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A", :value => 10},
      :item_b => {:name => "Item B"},
      :item_c => {
        :name => "Item C",
        :value => 15,
        :object => {:name => "Item C.1"}
      }
    })
    item_a = ConfigObject::Tester[:item_a]
    item_b = ConfigObject::Tester[:item_b]
    item_c = ConfigObject::Tester[:item_c]
    ConfigObject::Tester.all("name" => "Item A").should == [item_a]
    ConfigObject::Tester.all(:name => "Item B").should == [item_b]
    ConfigObject::Tester.all(:name => /A|B/).sort{|a,b| a.name <=> b.name}.should == [item_a, item_b]
    ConfigObject::Tester.all(:value => 15).should == [item_c]
    ConfigObject::Tester.all("object.name" => "Item C.1").should == [item_c]
  end
  
  it "should cache the result of finding objects by conditions" do
    ConfigObject::Tester.configure({
      :item_a => {:name => "Item A", :complex => 1},
      :item_b => {:name => "Item B", :complex => 2}
    })
    item_a = ConfigObject::Tester[:item_a]
    item_b = ConfigObject::Tester[:item_b]
    item_a.complex_called.should == 0
    items = ConfigObject::Tester.all(:complex => 1).should == [item_a]
    item_a.complex_called.should == 1
    items = ConfigObject::Tester.all(:complex => 1).should == [item_a]
    item_a.complex_called.should == 1
    items = ConfigObject::Tester.all(:complex => 2).should == [item_b]
    item_a.complex_called.should == 2
  end
  
  it "should call setter methods when initializing new objects" do
    config = ConfigObject::Tester.new(:name => "Name", :value => "10")
    config.name.should == "Name"
    config.value.should == 10
  end
  
  it "should set instance variables when no setter is defined when intializing new objects" do
    config = ConfigObject::Tester.new(:complex => "test", :no_attr => "here")
    config.complex.should == "test"
    config.instance_variable_get(:@no_attr).should == "here"
  end
  
  it "should duplicate and freeze the objects set in attributes" do
    name = "Item A"
    values = ["X", "Y"]
    type = "array"
    complex = {"values" => values, "type" => type}
    ConfigObject::Tester.configure({:item_a => {:name => name, :complex => complex}})
    item = ConfigObject::Tester[:item_a]
    
    item.name.should == name
    item.name.object_id.should_not == name.object_id
    item.complex.should == complex
    item.complex.object_id.should_not == complex.object_id
    item.complex["values"].object_id.should_not == values.object_id
    item.complex["type"].object_id.should_not == type.object_id
    
    name.should_not be_frozen
    complex.should_not be_frozen
    values.should_not be_frozen
    values.each{|v| v.should_not be_frozen}
    type.should_not be_frozen

    item.name.should be_frozen
    item.complex.should be_frozen
    item.complex["values"].should be_frozen
    item.complex["values"].each{|v| v.should be_frozen}
    item.complex["type"].should be_frozen
  end
  
  it "should not blow up when setting non-duplicable or non-freezable attributes" do
    array = [1, 2]
    array.freeze
    ConfigObject::Tester.configure({:item_a => {:name => nil, :value => 1, :object => true, :complex => array}})
  end
  
  it "should have an id attribute that is set by the configuration" do
    ConfigObject::Tester.configure(:item_a => {:name => "Item A"})
    ConfigObject::Tester[:item_a].id.should == "item_a"
  end
  
  it "should not share objects between classes" do
    ConfigObject::Tester.configure(:item_a => {:name => "Item A"})
    ConfigObject::Tester.ids.should == ["item_a"]
    ConfigObject::Tester2.ids.should == []
    ConfigObject::Tester2.configure(:item_b => {:name => "Item B"})
    ConfigObject::Tester.ids.should == ["item_a"]
    ConfigObject::Tester2.ids.should == ["item_b"]
  end
end
