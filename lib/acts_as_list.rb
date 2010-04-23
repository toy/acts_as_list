module ActsAsList''
  def acts_as_list(options = {})
    raise ArgumentError, "Hash expected, got #{options.class.name}" if not options.is_a?(Hash) and not options.empty?
    
    configuration = { :column => "position", :scope => "1 = 1" }
    configuration.update(options) unless options.nil?
    
    if configuration[:scope].is_a?(Symbol)
      configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].to_s !~ /_id$/
      scope_condition_method = %(
        def scope_condition
          if #{configuration[:scope].to_s}.nil?
            "#{configuration[:scope].to_s} IS NULL"
          else
            "#{configuration[:scope].to_s} = \#{#{configuration[:scope].to_s}}"
          end
        end
      )
    else
      scope_condition_method = "def scope_condition() \"#{configuration[:scope]}\" end"
    end

    class_eval <<-EOV
      def acts_as_list_class
        ::#{self.name}
      end

      def position_column
        '#{configuration[:column]}'
      end

      #{scope_condition_method}

      before_destroy :remove_from_list
      before_create  :add_to_list_bottom
    EOV
    
    include InstanceMethods
  end
  
  # All the methods available to a record that has had <tt>acts_as_list</tt> specified. Each method works
  # by assuming the object to be the item in the list, so <tt>chapter.move_lower</tt> would move that chapter
  # lower in the list of all chapters. Likewise, <tt>chapter.first?</tt> would return +true+ if that chapter is
  # the first in the list of all chapters.
  module InstanceMethods
    # Insert the item at the given position (defaults to the top position of 1).
    def insert_at(position = 1)
      insert_at_position(position)
    end

    # Swap positions with the next lower item, if one exists.
    def move_lower
      return unless lower_item

      acts_as_list_class.transaction do
        lower_item.decrement_position
        increment_position
      end
    end

    # Swap positions with the next higher item, if one exists.
    def move_higher
      return unless higher_item

      acts_as_list_class.transaction do
        higher_item.increment_position
        decrement_position
      end
    end

    # Move to the bottom of the list. If the item is already in the list, the items below it have their
    # position adjusted accordingly.
    def move_to_bottom
      return unless in_list?
      acts_as_list_class.transaction do
        decrement_positions_on_lower_items
        assume_bottom_position
      end
    end

    # Move to the top of the list. If the item is already in the list, the items above it have their
    # position adjusted accordingly.
    def move_to_top
      return unless in_list?
      acts_as_list_class.transaction do
        increment_positions_on_higher_items
        assume_top_position
      end
    end

    # Removes the item from the list.
    def remove_from_list
      if in_list?
        decrement_positions_on_lower_items
        update_attribute(position_column, nil)
      end
    end

    # Increase the position of this item without adjusting the rest of the list.
    def increment_position
      return unless in_list?
      update_attribute position_column, self.send(position_column).to_i + 1
    end

    # Decrease the position of this item without adjusting the rest of the list.
    def decrement_position
      return unless in_list?
      update_attribute position_column, self.send(position_column).to_i - 1
    end

    # Return +true+ if this object is the first in the list.
    def first?
      return false unless in_list?
      self.send(position_column) == 1
    end

    # Return +true+ if this object is the last in the list.
    def last?
      return false unless in_list?
      self.send(position_column) == bottom_position_in_list
    end

    # Test if this record is in a list
    def in_list?
      !send(position_column).nil?
    end

    private
      def add_to_list_top
        increment_positions_on_all_items
      end

      def add_to_list_bottom
        self[position_column] = bottom_position_in_list.to_i + 1
      end

      # Overwrite this method to define the scope of the list changes
      def scope_condition() "1" end

      # Returns the bottom position number in the list.
      #   bottom_position_in_list    # => 2
      def bottom_position_in_list(except = nil)
        item = bottom_item(except)
        item ? item.send(position_column) : 0
      end

      # Forces item to assume the bottom position in the list.
      def assume_bottom_position
        update_attribute(position_column, bottom_position_in_list(self).to_i + 1)
      end

      # Forces item to assume the top position in the list.
      def assume_top_position
        update_attribute(position_column, 1)
      end

      def insert_at_position(position)
        remove_from_list
        increment_positions_on_lower_items(position)
        self.update_attribute(position_column, position)
      end
  end
end

# Use appropriate ActiveRecord methods
if not defined?(Rails) or Rails::VERSION::MAJOR == 2
  require 'acts_as_list/rails2'
elsif Rails::VERSION::MAJOR == 3
  require 'acts_as_list/rails3'
else
  raise Exception, "Rails 2.x or Rails 3.x expected, got Rails #{Rails::VERSION::MAJOR}.x"
end

# Extend ActiveRecord's functionality
ActiveRecord::Base.extend ActsAsList

