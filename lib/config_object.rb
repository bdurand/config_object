require 'yaml'
require 'erb'
require 'pathname'

# Classes that include ConfigObject can then be loaded from configuration using the ClassMethods. The objects
# themselves will have an +id+ method as well as an initializer that sets attributes from a hash (see Attributes
# for details).
module ConfigObject
  
  def self.included (base) #:nodoc:
    base.extend(ClassMethods)
    base.send :include, Attributes
  end
  
  module ClassMethods
    DEFAULTS = 'defaults'
    
    # Find a configuration object by it's identifier or by a conditions hash.
    #
    # Identifiers are always looked up by string so find(:production) is the same as find('production').
    #
    # Condition hashes are used to select an item based on the field values. A match is made when either
    # the attribute value matches a hash value. Hash values may be regular expressions. Matches are cached
    # so there is no overhead in looking up a value by conditions multiple times.
    #
    # See #all for examples.
    def find (id_or_conditions)
      if id_or_conditions.is_a?(Hash)
        lookup(id_or_conditions).first
      else
        configs[id_or_conditions.to_s]
      end
    end
    
    alias_method :[], :find
    
    # Find all configuration objects that match the conditions hash.
    #
    # Condition hashes are used to select an item based on the field values. A match is made when either
    # the attribute value matches a hash value. Hash values may be regular expressions. Matches are cached
    # so there is no overhead in looking up a value by conditions multiple times.
    #
    # Examples (assumes the City class includes ConfigObject):
    #
    #   City.all(:name => "Springfield") # find all cities named Springfield
    #   City.all("state.name" => "Illinois") # find all cities where the state object has a name of Illinois
    #   City.all("population.>" => 1000000) # find all cities where population is greater than one million
    #   City.all("transportation.include?" => "train") # find all cities where transportation includes "train"
    #   City.all(:name => /^New/) # find all cities that start with "New"
    def all (conditions = {})
      if conditions.size == 0
        configs.values
      else
        lookup(conditions)
      end
    end
    
    # Get an array of ids for all configuration objects.
    def ids
      configs.keys
    end
    
    # Force the configuration objects to be reloaded from the configuration files.
    # Any observers will be notified by invoking the callback provided.
    def reload
      @configs = nil
      @cache = {}
      notify_observers
      nil
    end
    
    # Set default values for the attributes for all configuration objects.
    #
    # Calling this method multiple times will merge the default values with those from
    # previous calls.
    def set_defaults (values)
      @defaults ||= {}
      @defaults.merge!(stringify_keys(values))
      reload
    end
    
    # Add an observer to the configuration class. Whenever the configuration is reloaded,
    # observers will be notified by either invoking the callback method provided or by
    # calling the block.
    def add_observer (observer, callback = nil, &block)
      @observers ||= {}
      @observers[observer] = callback || block
      observer
    end
    
    # Remove an observer so it no longer receives notifications when the configuration is reloaded.
    def remove_observer (observer)
      @observers.delete(observer) if observer
      observer
    end
    
    # Configure objects with a hash. This can be used in lieu of configuration files
    # if you need to configure objects through code like in a Rails initializer.
    # The argument passed in must be a hash where the keys are the configuration
    # object ids and the values are the configuration attribute values.
    #
    # If this method is called multiple times, the values for each configuration
    # object will be merged with the values from previous calls.
    #
    # Defaults can be set by using the special id "defaults" as one of the keys.
    def configure (config_options)
      @configure_hash ||= {}
      config_options.each_pair do |id, values|
        id = id.to_s
        if id == DEFAULTS
          set_defaults(values)
        else
          existing_values = @configure_hash[id] || {}
          @configure_hash[id] = existing_values.merge(values)
        end
      end
      reload
    end
    
    # Set the files used to load the configuration objects. Each file will be read in the
    # order specified. Values in later files will be merged into values specified in earlier
    # files. This allows later files to serve as overrides for the earlier files and is
    # ideal for specifying envrionment dependent settings.
    def configuration_files= (*files)
      @configuration_files = files.flatten.collect{|f| f.is_a?(Pathname) ? f : Pathname.new(f)}
      reload
      @configuration_files
    end

    # Get the list of files used to load the configuration. If the list is changed, you
    # should call reload to ensure the new files are read.
    def configuration_files
      @configuration_files ||= []
    end
    
    # Clear all configuration settings. Mostly made available for testing purposes.
    def clear
      @configure_hash = nil
      @configuration_files = nil
      @defaults = nil
      reload
    end
    
    protected
    
    # Notify all observers that the configuration has changed
    def notify_observers
      @observers.each_pair do |observer, callback|
        args = []
        callback = observer.method(callback) unless callback.is_a?(Proc)
        args << self if callback.arity == 1 || callback.arity == -2
        callback.call(*args)
      end if @observers
    end
    
    # Determine if an object attribute matches the specified value.
    def object_matches? (object, attribute, match_value) #:nodoc:
      attribute = attribute.to_s.split('.') unless attribute.is_a?(Array)
      method_name = attribute.first
      if object.respond_to?(method_name)
        arity = object.method(method_name).arity
        # If this is the last attribute in a chain and the method requires a single argument, call the method with the match value.
        if arity == 1 or arity == -2 and attribute.length == 1
          return !!object.send(method_name, match_value)
        end
        value = object.send(method_name)
      end
      if value
        if attribute.size > 1
          return object_matches?(value, attribute[1, attribute.size], match_value)
        else
          if match_value.is_a?(Regexp)
            return value.is_a?(String) && value.match(match_value)
          else
            return value == match_value
          end
        end
      else
        return match_value.nil?
      end
    end
    
    # Get the hash that contains all the configs mapping the ids to the objects.
    def configs #:nodoc:
      unless @configs
        @cache = {}
        hashes = {}
        new_defaults = {}
        configuration_files.each do |file|
          file = Pathname.new(file) unless file.is_a?(Pathname)
          load_yaml_file(file).each_pair do |id, values|
            load_config_hash(hashes, new_defaults, id, values)
          end
        end
        if @configure_hash
          @configure_hash.each do |id, values|
            load_config_hash(hashes, new_defaults, id, values)
          end
        end
        @defaults ||= {}
        @defaults = new_defaults.merge(@defaults)
        @configs = {}
        hashes.each_pair do |id, values|
          @configs[id.to_s] = new(@defaults.merge(values.merge('id' => id)))
        end
      end
      return @configs
    end
    
    # Look up items based on the conditions specified as a hash. Lookups are cached so they can be safely
    # invoked over and over without incurring a performance penalty.
    def lookup (conditions) #:nodoc:
      @cache ||= {}
      values = @cache[conditions]
      unless values
        values = configs.values.select do |obj|
          conditions.all? do |attribute, match_value|
            object_matches?(obj, attribute, match_value)
          end
        end
        @cache[conditions] = values
      end
      return values.dup
    end
    
    private
    
    def load_config_hash (options, default_options, id, values) #:nodoc:
      raise ArgumentError.new("Values defined for #{id} must be a hash") unless values.is_a?(Hash)
      id = id.to_s
      values = stringify_keys(values)
      if id == DEFAULTS
        default_options.merge!(values)
      else
        values = options[id].merge(values) if options[id]
        options[id] = values
      end
    end
    
    def stringify_keys (hash) #:nodoc:
      hash.inject({}) do |options, (key, value)|
        options[key.to_s] = value
        options
      end
    end
    
    # Load a YAML file into a hash. If the specified file is a directory,
    # all *.yml or *.yaml files will be loaded as the values with the file
    # base name used as the key. This process is recursive.
    def load_yaml_file (file) #:nodoc:
      if file.exist? and (file.directory? or [".yaml", ".yml"].include?(file.extname.downcase))
        if file.directory?
          vals = {}
          file.children.each do |child|
            key = child.basename.to_s.sub(/\.y(a?)ml$/i, '')
            vals[key] = load_yaml_file(child)
          end
          return vals
        else
          yaml = file.read
          if yaml.nil? or yaml.gsub(/\s/, '').size == 0
            return {}
          else
            return YAML.load(ERB.new(yaml).result) || {}
          end
        end
      else
        return {}
      end
    end
  end

  # This module adds an initializer that sets attributes from a hash.
  module Attributes
    # Create a new configuration object with the specified attributes. Attributes are set by
    # calling the setter method for each key if it exists. If there is no setter, an instance
    # variable will be set. The value set will be duplicated and frozen if possible so that
    # it can't be accidentally changed by calling a destructive method on it.
    def initialize (attributes)
      attributes.each_pair do |name, value|
        setter = "#{name}=".to_sym
        value = deep_freeze(value)
        if respond_to?(setter)
          send(setter, value)
        else
          instance_variable_set("@#{name}", value)
        end
      end
    end
  
    protected
  
    # Freeze a duplicate of the value passed in so that consumers of the configuration object
    # don't accidentally change it by calling destructive methods on the original copy.
    # For hashes and arrays recusively freezes every element.
    def deep_freeze (value)
      if value.is_a?(Hash)
        frozen = {}
        value.each_pair{|k, v| frozen[k] = deep_freeze(v)}
        value = frozen
      elsif value.is_a?(Array)
        value = value.collect{|v| deep_freeze(v)}
      else
        if value and !value.is_a?(Numeric)
          value = value.dup rescue value
        end
      end
      value.freeze unless value.frozen?
      return value
    rescue
      return value
    end
  end

  # Id is the only attribute defined for all config objects. It will be set when the configuration is loaded.
  def id
    @id
  end
end
